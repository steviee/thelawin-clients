using System.Net.Http.Json;
using System.Text.Json;

namespace Thelawin;

/// <summary>Main client for interacting with the thelawin.dev API</summary>
public class ThelawinClient : IDisposable
{
    private readonly string _apiKey;
    private readonly string _apiUrl;
    private readonly HttpClient _httpClient;
    private readonly JsonSerializerOptions _jsonOptions;
    private readonly bool _ownsHttpClient;

    /// <summary>Create a new ThelawinClient</summary>
    public ThelawinClient(string apiKey, string? apiUrl = null, TimeSpan? timeout = null, HttpClient? httpClient = null)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new ArgumentException("API key is required", nameof(apiKey));

        _apiKey = apiKey;
        _apiUrl = (apiUrl ?? "https://api.thelawin.dev").TrimEnd('/');
        _ownsHttpClient = httpClient == null;
        _httpClient = httpClient ?? new HttpClient { Timeout = timeout ?? TimeSpan.FromSeconds(30) };
        _jsonOptions = new JsonSerializerOptions
        {
            PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
            DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull
        };
    }

    /// <summary>Create a new invoice builder</summary>
    public InvoiceBuilder Invoice() => new(this);

    /// <summary>Generate an invoice directly</summary>
    public async Task<InvoiceResult> GenerateInvoiceAsync(GenerateRequest request, CancellationToken cancellationToken = default)
    {
        try
        {
            using var httpRequest = new HttpRequestMessage(HttpMethod.Post, $"{_apiUrl}/v1/generate")
            {
                Content = JsonContent.Create(request, options: _jsonOptions)
            };
            httpRequest.Headers.Add("X-API-Key", _apiKey);

            using var response = await _httpClient.SendAsync(httpRequest, cancellationToken);

            return await HandleGenerateResponseAsync(response, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            throw new ThelawinNetworkException("Network error", ex);
        }
        catch (TaskCanceledException ex) when (ex.InnerException is TimeoutException)
        {
            throw new ThelawinNetworkException("Request timeout", ex);
        }
    }

    /// <summary>Extract invoice data from an existing PDF or XML document</summary>
    public async Task<RetrieveResponse> RetrieveAsync(
        string dataBase64,
        string? contentType = null,
        bool includeSourceXml = false,
        CancellationToken ct = default)
    {
        try
        {
            var payload = new Dictionary<string, object?>
            {
                ["data_base64"] = dataBase64
            };
            if (contentType != null)
                payload["content_type"] = contentType;
            if (includeSourceXml)
                payload["include_source_xml"] = true;

            using var httpRequest = new HttpRequestMessage(HttpMethod.Post, $"{_apiUrl}/v1/retrieve")
            {
                Content = JsonContent.Create(payload, options: _jsonOptions)
            };
            httpRequest.Headers.Add("X-API-Key", _apiKey);

            using var response = await _httpClient.SendAsync(httpRequest, ct);

            var content = await response.Content.ReadAsStringAsync(ct);

            if (response.IsSuccessStatusCode)
            {
                return JsonSerializer.Deserialize<RetrieveResponse>(content, _jsonOptions)!;
            }

            ErrorResponse? error;
            try
            {
                error = JsonSerializer.Deserialize<ErrorResponse>(content, _jsonOptions);
            }
            catch
            {
                error = new ErrorResponse("unknown_error", $"HTTP {(int)response.StatusCode}");
            }

            var statusCode = (int)response.StatusCode;

            if (statusCode == 402)
                throw new ThelawinQuotaExceededException(error?.Message ?? "Quota exceeded");

            throw new ThelawinApiException(
                error?.Message ?? error?.Error ?? "Unknown error",
                statusCode,
                error?.Error
            );
        }
        catch (HttpRequestException ex)
        {
            throw new ThelawinNetworkException("Network error", ex);
        }
        catch (TaskCanceledException ex) when (ex.InnerException is TimeoutException)
        {
            throw new ThelawinNetworkException("Request timeout", ex);
        }
    }

    private async Task<InvoiceResult> HandleGenerateResponseAsync(HttpResponseMessage response, CancellationToken cancellationToken)
    {
        var content = await response.Content.ReadAsStringAsync(cancellationToken);

        if (response.IsSuccessStatusCode)
        {
            var data = JsonSerializer.Deserialize<GenerateResponse>(content, _jsonOptions)!;
            return new InvoiceSuccess(data.PdfBase64, data.Filename, data.Validation, data.Account);
        }

        ErrorResponse? error;
        try
        {
            error = JsonSerializer.Deserialize<ErrorResponse>(content, _jsonOptions);
        }
        catch
        {
            error = new ErrorResponse("unknown_error", $"HTTP {(int)response.StatusCode}");
        }

        var statusCode = (int)response.StatusCode;

        if (statusCode == 402)
        {
            throw new ThelawinQuotaExceededException(error?.Message ?? "Quota exceeded");
        }

        if (statusCode == 422 && error?.Details != null)
        {
            return new InvoiceFailure(error.Details);
        }

        throw new ThelawinApiException(
            error?.Message ?? error?.Error ?? "Unknown error",
            statusCode,
            error?.Error
        );
    }

    /// <summary>Validate an existing PDF</summary>
    public async Task<ValidationResult> ValidateAsync(string pdfBase64, CancellationToken cancellationToken = default)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, $"{_apiUrl}/v1/validate")
            {
                Content = JsonContent.Create(new { pdf_base64 = pdfBase64 })
            };
            request.Headers.Add("X-API-Key", _apiKey);

            using var response = await _httpClient.SendAsync(request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadFromJsonAsync<ErrorResponse>(cancellationToken: cancellationToken);
                throw new ThelawinApiException(
                    error?.Message ?? "Validation failed",
                    (int)response.StatusCode,
                    error?.Error
                );
            }

            return (await response.Content.ReadFromJsonAsync<ValidationResult>(cancellationToken: cancellationToken))!;
        }
        catch (HttpRequestException ex)
        {
            throw new ThelawinNetworkException("Network error", ex);
        }
    }

    /// <summary>Get account information</summary>
    public async Task<AccountInfo> GetAccountAsync(CancellationToken cancellationToken = default)
    {
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Get, $"{_apiUrl}/v1/account");
            request.Headers.Add("X-API-Key", _apiKey);

            using var response = await _httpClient.SendAsync(request, cancellationToken);

            if (!response.IsSuccessStatusCode)
            {
                var error = await response.Content.ReadFromJsonAsync<ErrorResponse>(cancellationToken: cancellationToken);
                throw new ThelawinApiException(
                    error?.Message ?? "Failed to get account",
                    (int)response.StatusCode,
                    error?.Error
                );
            }

            return (await response.Content.ReadFromJsonAsync<AccountInfo>(cancellationToken: cancellationToken))!;
        }
        catch (HttpRequestException ex)
        {
            throw new ThelawinNetworkException("Network error", ex);
        }
    }

    public void Dispose()
    {
        if (_ownsHttpClient)
        {
            _httpClient.Dispose();
        }
        GC.SuppressFinalize(this);
    }
}
