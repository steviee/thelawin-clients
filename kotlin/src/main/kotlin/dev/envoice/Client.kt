package dev.envoice

import io.ktor.client.*
import io.ktor.client.call.*
import io.ktor.client.engine.cio.*
import io.ktor.client.plugins.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.client.statement.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.serialization.json.Json
import java.io.Closeable

/**
 * Main client for interacting with the envoice.dev API
 */
class EnvoiceClient(
    private val apiKey: String,
    private val apiUrl: String = "https://api.envoice.dev",
    private val timeout: Long = 30000L,
    private val httpClient: HttpClient? = null
) : Closeable {

    init {
        require(apiKey.isNotBlank()) { "API key is required" }
    }

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = false
    }

    private val client: HttpClient = httpClient ?: HttpClient(CIO) {
        install(ContentNegotiation) {
            json(json)
        }
        install(HttpTimeout) {
            requestTimeoutMillis = timeout
            connectTimeoutMillis = 10000L
        }
        defaultRequest {
            header("X-API-Key", apiKey)
        }
    }

    private val ownsClient = httpClient == null

    /**
     * Create a new invoice builder with fluent API
     */
    fun invoice(): InvoiceBuilder = InvoiceBuilder(this)

    /**
     * Generate an invoice directly (without builder)
     */
    suspend fun generateInvoice(request: GenerateRequest): InvoiceResult {
        return try {
            val response: HttpResponse = client.post("$apiUrl/v1/generate") {
                contentType(ContentType.Application.Json)
                setBody(request)
            }

            handleGenerateResponse(response)
        } catch (e: HttpRequestTimeoutException) {
            throw EnvoiceNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is EnvoiceException) throw e
            throw EnvoiceNetworkException(e.message ?: "Unknown error", e)
        }
    }

    private suspend fun handleGenerateResponse(response: HttpResponse): InvoiceResult {
        return when (response.status.value) {
            200 -> {
                val data: GenerateResponse = response.body()
                InvoiceResult.Success(
                    pdfBase64 = data.pdfBase64,
                    filename = data.filename,
                    validation = data.validation,
                    account = data.account
                )
            }
            402 -> {
                val error: ErrorResponse = response.body()
                throw EnvoiceQuotaExceededException(error.message ?: "Quota exceeded")
            }
            422 -> {
                val error: ErrorResponse = response.body()
                if (error.details != null) {
                    InvoiceResult.Failure(error.details)
                } else {
                    throw EnvoiceApiException(
                        error.message ?: error.error,
                        response.status.value,
                        error.error
                    )
                }
            }
            else -> {
                val error: ErrorResponse = try {
                    response.body()
                } catch (e: Exception) {
                    ErrorResponse("unknown_error", "HTTP ${response.status.value}")
                }
                throw EnvoiceApiException(
                    error.message ?: error.error,
                    response.status.value,
                    error.error
                )
            }
        }
    }

    /**
     * Validate an existing PDF for ZUGFeRD/Factur-X compliance
     */
    suspend fun validate(pdfBase64: String): Map<String, Any?> {
        return try {
            val response: HttpResponse = client.post("$apiUrl/v1/validate") {
                contentType(ContentType.Application.Json)
                setBody(mapOf("pdf_base64" to pdfBase64))
            }

            if (!response.status.isSuccess()) {
                val error: ErrorResponse = response.body()
                throw EnvoiceApiException(
                    error.message ?: error.error,
                    response.status.value,
                    error.error
                )
            }

            response.body()
        } catch (e: HttpRequestTimeoutException) {
            throw EnvoiceNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is EnvoiceException) throw e
            throw EnvoiceNetworkException(e.message ?: "Unknown error", e)
        }
    }

    /**
     * Get account information (quota, plan, etc.)
     */
    suspend fun getAccount(): AccountInfo {
        return try {
            val response: HttpResponse = client.get("$apiUrl/v1/account")

            if (!response.status.isSuccess()) {
                val error: ErrorResponse = response.body()
                throw EnvoiceApiException(
                    error.message ?: error.error,
                    response.status.value,
                    error.error
                )
            }

            response.body()
        } catch (e: HttpRequestTimeoutException) {
            throw EnvoiceNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is EnvoiceException) throw e
            throw EnvoiceNetworkException(e.message ?: "Unknown error", e)
        }
    }

    override fun close() {
        if (ownsClient) {
            client.close()
        }
    }
}
