package dev.envoice;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.time.Duration;

/**
 * Main client for interacting with the envoice.dev API
 */
public final class EnvoiceClient implements AutoCloseable {
    private final String apiKey;
    private final String apiUrl;
    private final Duration timeout;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;

    /**
     * Create a new EnvoiceClient with default options
     */
    public EnvoiceClient(String apiKey) {
        this(apiKey, "https://api.envoice.dev", Duration.ofSeconds(30));
    }

    /**
     * Create a new EnvoiceClient with custom options
     */
    public EnvoiceClient(String apiKey, String apiUrl, Duration timeout) {
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
     * Generate an invoice directly
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
            throw new Exceptions.EnvoiceNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.EnvoiceNetworkException("Request interrupted", e);
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
            throw new Exceptions.EnvoiceQuotaExceededException(
                error.message() != null ? error.message() : "Quota exceeded"
            );
        }

        if (status == 422 && error.details() != null) {
            return new InvoiceResult.Failure(error.details());
        }

        throw new Exceptions.EnvoiceApiException(
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
                throw new Exceptions.EnvoiceApiException(
                    error.message() != null ? error.message() : error.error(),
                    response.statusCode(),
                    error.error()
                );
            }

            return objectMapper.readValue(response.body(), Types.ValidationResult.class);
        } catch (IOException e) {
            throw new Exceptions.EnvoiceNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.EnvoiceNetworkException("Request interrupted", e);
        }
    }

    /**
     * Get account information
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
                throw new Exceptions.EnvoiceApiException(
                    error.message() != null ? error.message() : error.error(),
                    response.statusCode(),
                    error.error()
                );
            }

            return objectMapper.readValue(response.body(), Types.AccountInfo.class);
        } catch (IOException e) {
            throw new Exceptions.EnvoiceNetworkException("Network error", e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new Exceptions.EnvoiceNetworkException("Request interrupted", e);
        }
    }

    @Override
    public void close() {
        // HttpClient doesn't need explicit closing in this implementation
    }
}
