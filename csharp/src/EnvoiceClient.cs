using System.Net.Http.Json;
using System.Text.Json;

namespace Envoice;

/// <summary>Main client for interacting with the envoice.dev API</summary>
public class EnvoiceClient : IDisposable
{
    private readonly string _apiKey;
    private readonly string _apiUrl;
    private readonly HttpClient _httpClient;
    private readonly JsonSerializerOptions _jsonOptions;
    private readonly bool _ownsHttpClient;

    /// <summary>Create a new EnvoiceClient</summary>
    public EnvoiceClient(string apiKey, string? apiUrl = null, TimeSpan? timeout = null, HttpClient? httpClient = null)
    {
        if (string.IsNullOrWhiteSpace(apiKey))
            throw new ArgumentException("API key is required", nameof(apiKey));

        _apiKey = apiKey;
        _apiUrl = (apiUrl ?? "https://api.envoice.dev").TrimEnd('/');
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
            throw new EnvoiceNetworkException("Network error", ex);
        }
        catch (TaskCanceledException ex) when (ex.InnerException is TimeoutException)
        {
            throw new EnvoiceNetworkException("Request timeout", ex);
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
            throw new EnvoiceQuotaExceededException(error?.Message ?? "Quota exceeded");
        }

        if (statusCode == 422 && error?.Details != null)
        {
            return new InvoiceFailure(error.Details);
        }

        throw new EnvoiceApiException(
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
                throw new EnvoiceApiException(
                    error?.Message ?? "Validation failed",
                    (int)response.StatusCode,
                    error?.Error
                );
            }

            return (await response.Content.ReadFromJsonAsync<ValidationResult>(cancellationToken: cancellationToken))!;
        }
        catch (HttpRequestException ex)
        {
            throw new EnvoiceNetworkException("Network error", ex);
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
                throw new EnvoiceApiException(
                    error?.Message ?? "Failed to get account",
                    (int)response.StatusCode,
                    error?.Error
                );
            }

            return (await response.Content.ReadFromJsonAsync<AccountInfo>(cancellationToken: cancellationToken))!;
        }
        catch (HttpRequestException ex)
        {
            throw new EnvoiceNetworkException("Network error", ex);
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
