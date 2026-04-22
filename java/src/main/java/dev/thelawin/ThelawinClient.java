package dev.thelawin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * Main client for interacting with the thelawin.dev API.
 *
 * <p>Usage:</p>
 * <pre>{@code
 * try (var client = new ThelawinClient("tlw_sandbox_...")) {
 *     var result = client.invoice()
 *         .number("2026-001")
 *         .date("2026-01-15")
 *         .seller(Types.Party.builder("Acme GmbH").vatId("DE123456789").build())
 *         .buyer(Types.Party.builder("Customer AG").build())
 *         .addItem(Types.LineItem.builder("Consulting").unitPrice(150.0).build())
 *         .generate();
 * }
 * }</pre>
 */
public final class ThelawinClient implements AutoCloseable {
    private final String apiKey;
    private final String apiUrl;
    private final Duration timeout;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;

    /**
     * Create a new ThelawinClient with default options
     */
    public ThelawinClient(String apiKey) {
        this(apiKey, "https://api.thelawin.dev", Duration.ofSeconds(30));
    }

    /**
     * Create a new ThelawinClient with a custom base URL
     */
    public ThelawinClient(String apiKey, String apiUrl) {
        this(apiKey, apiUrl, Duration.ofSeconds(30));
    }

    /**
     * Create a new ThelawinClient with custom options
     */
    public ThelawinClient(String apiKey, String apiUrl, Duration timeout) {
        if (apiKey == null || apiKey.isBlank()) {
            throw new IllegalArgumentException("API key is required");
        }
        this.apiKey = apiKey;
        this.apiUrl = apiUrl.replaceAll("/$", "");
        this.timeout = timeout;
        this.httpClient = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(10))
            .build();
        this.objectMapper = new ObjectMapper()
            .registerModule(new JavaTimeModule());
    }

    /**
     * Create a new invoice builder
     */
    public InvoiceBuilder invoice() {
        return new InvoiceBuilder(this);
    }

    /**
     * Generate an invoice directly from a request object
     */
    public InvoiceResult generateInvoice(Types.GenerateRequest request) {
        try {
            String body = objectMapper.writeValueAsString(request);

            HttpRequest httpRequest = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl + "/v1/generate"))
                .header("Content-Type", "application/json")
                .header("X-API-Key", apiKey)
                .timeout(timeout)
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

            HttpResponse<String> response = httpClient.send(httpRequest, HttpResponse.BodyHandlers.ofString());

            return handleGenerateResponse(response);
        } catch (IOException e) {
            throw new Exceptions.ThelawinNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.ThelawinNetworkException("Request interrupted", e);
        }
    }

    private InvoiceResult handleGenerateResponse(HttpResponse<String> response) throws IOException {
        int status = response.statusCode();
        String body = response.body();

        if (status == 200) {
            Types.GenerateResponse data = objectMapper.readValue(body, Types.GenerateResponse.class);
            return new InvoiceResult.Success(
                data.pdfBase64(),
                data.filename(),
                data.validation(),
                data.account()
            );
        }

        Types.ErrorResponse error;
        try {
            error = objectMapper.readValue(body, Types.ErrorResponse.class);
        } catch (Exception e) {
            error = new Types.ErrorResponse("unknown_error", "HTTP " + status, null);
        }

        if (status == 402) {
            throw new Exceptions.ThelawinQuotaExceededException(
                error.message() != null ? error.message() : "Quota exceeded"
            );
        }

        if (status == 422 && error.details() != null) {
            return new InvoiceResult.Failure(error.details());
        }

        throw new Exceptions.ThelawinApiException(
            error.message() != null ? error.message() : error.error(),
            status,
            error.error()
        );
    }

    /**
     * Validate an existing PDF
     */
    public Types.ValidationResult validate(String pdfBase64) {
        try {
            String body = objectMapper.writeValueAsString(java.util.Map.of("pdf_base64", pdfBase64));

            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl + "/v1/validate"))
                .header("Content-Type", "application/json")
                .header("X-API-Key", apiKey)
                .timeout(timeout)
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                Types.ErrorResponse error = objectMapper.readValue(response.body(), Types.ErrorResponse.class);
                throw new Exceptions.ThelawinApiException(
                    error.message() != null ? error.message() : error.error(),
                    response.statusCode(),
                    error.error()
                );
            }

            return objectMapper.readValue(response.body(), Types.ValidationResult.class);
        } catch (IOException e) {
            throw new Exceptions.ThelawinNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.ThelawinNetworkException("Request interrupted", e);
        }
    }

    /**
     * Extract invoice data from an existing PDF or XML file.
     *
     * @param dataBase64      Base64-encoded PDF or XML content
     * @param contentType     MIME type, e.g. "application/pdf" or "application/xml"
     * @param includeSourceXml whether to include the raw XML in the response
     * @return parsed invoice data with format detection
     */
    public Types.RetrieveResponse retrieve(String dataBase64, String contentType, boolean includeSourceXml) {
        try {
            var payload = new Types.RetrieveRequest(dataBase64, contentType, includeSourceXml);
            String body = objectMapper.writeValueAsString(payload);

            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl + "/v1/retrieve"))
                .header("Content-Type", "application/json")
                .header("X-API-Key", apiKey)
                .timeout(timeout)
                .POST(HttpRequest.BodyPublishers.ofString(body))
                .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                Types.ErrorResponse error;
                try {
                    error = objectMapper.readValue(response.body(), Types.ErrorResponse.class);
                } catch (Exception e) {
                    error = new Types.ErrorResponse("unknown_error", "HTTP " + response.statusCode(), null);
                }
                throw new Exceptions.ThelawinApiException(
                    error.message() != null ? error.message() : error.error(),
                    response.statusCode(),
                    error.error()
                );
            }

            return objectMapper.readValue(response.body(), Types.RetrieveResponse.class);
        } catch (IOException e) {
            throw new Exceptions.ThelawinNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.ThelawinNetworkException("Request interrupted", e);
        }
    }

    /**
     * Get account information (quota, plan, overage)
     */
    public Types.AccountInfo getAccount() {
        try {
            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl + "/v1/account"))
                .header("X-API-Key", apiKey)
                .timeout(timeout)
                .GET()
                .build();

            HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() != 200) {
                Types.ErrorResponse error = objectMapper.readValue(response.body(), Types.ErrorResponse.class);
                throw new Exceptions.ThelawinApiException(
                    error.message() != null ? error.message() : error.error(),
                    response.statusCode(),
                    error.error()
                );
            }

            return objectMapper.readValue(response.body(), Types.AccountInfo.class);
        } catch (IOException e) {
            throw new Exceptions.ThelawinNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.ThelawinNetworkException("Request interrupted", e);
        }
    }

    @Override
    public void close() {
        // HttpClient doesn't need explicit closing in this implementation
    }
}
