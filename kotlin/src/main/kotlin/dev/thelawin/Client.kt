package dev.thelawin

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
 * Haupt-Client fuer die thelawin.dev API
 *
 * Beispiel:
 * ```kotlin
 * val client = ThelawinClient("env_sandbox_xxx")
 * val result = client.invoice()
 *     .number("2026-001")
 *     .date("2026-01-15")
 *     .format(InvoiceFormat.ZUGFERD)
 *     .seller { name = "Acme GmbH"; vatId = "DE123456789" }
 *     .buyer { name = "Customer AG" }
 *     .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
 *     .generate()
 * ```
 */
class ThelawinClient(
    private val apiKey: String,
    private val apiUrl: String = "https://api.thelawin.dev",
    private val timeout: Long = 30000L,
    private val httpClient: HttpClient? = null
) : Closeable {

    init {
        require(apiKey.isNotBlank()) { "API key is required" }
    }

    internal val json = Json {
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
     * Neuen InvoiceBuilder mit Fluent-API erzeugen
     */
    fun invoice(): InvoiceBuilder = InvoiceBuilder(this)

    /**
     * Rechnung direkt generieren (ohne Builder)
     */
    suspend fun generateInvoice(request: GenerateRequest): InvoiceResult {
        return try {
            val response: HttpResponse = client.post("$apiUrl/v1/generate") {
                contentType(ContentType.Application.Json)
                header("X-API-Key", apiKey)
                setBody(request)
            }

            handleGenerateResponse(response)
        } catch (e: HttpRequestTimeoutException) {
            throw ThelawinNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is ThelawinException) throw e
            throw ThelawinNetworkException(e.message ?: "Unknown error", e)
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
            401 -> {
                val error: ErrorResponse = response.body()
                throw ThelawinAuthException(error.message ?: "Unauthorized")
            }
            402 -> {
                val error: ErrorResponse = response.body()
                throw ThelawinQuotaExceededException(error.message ?: "Quota exceeded")
            }
            422 -> {
                val error: ErrorResponse = response.body()
                if (error.details != null) {
                    InvoiceResult.Failure(error.details)
                } else {
                    throw ThelawinApiException(
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
                throw ThelawinApiException(
                    error.message ?: error.error,
                    response.status.value,
                    error.error
                )
            }
        }
    }

    /**
     * Rechnungsdaten validieren (Pre-Validation ohne PDF-Erzeugung)
     */
    suspend fun validate(request: ValidateRequest): ValidateResponse {
        return try {
            val response: HttpResponse = client.post("$apiUrl/v1/validate") {
                contentType(ContentType.Application.Json)
                header("X-API-Key", apiKey)
                setBody(request)
            }

            when (response.status.value) {
                200 -> response.body()
                401 -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinAuthException(error.message ?: "Unauthorized")
                }
                else -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinApiException(
                        error.message ?: error.error,
                        response.status.value,
                        error.error
                    )
                }
            }
        } catch (e: HttpRequestTimeoutException) {
            throw ThelawinNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is ThelawinException) throw e
            throw ThelawinNetworkException(e.message ?: "Unknown error", e)
        }
    }

    /**
     * Rechnungsdaten aus PDF/XML extrahieren (Reverse von /generate)
     */
    suspend fun retrieve(
        dataBase64: String,
        contentType: String? = null,
        includeSourceXml: Boolean = false
    ): RetrieveResponse {
        return try {
            val request = RetrieveRequest(
                dataBase64 = dataBase64,
                contentType = contentType,
                includeSourceXml = includeSourceXml
            )

            val response: HttpResponse = client.post("$apiUrl/v1/retrieve") {
                contentType(ContentType.Application.Json)
                header("X-API-Key", apiKey)
                setBody(request)
            }

            when (response.status.value) {
                200 -> response.body()
                401 -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinAuthException(error.message ?: "Unauthorized")
                }
                402 -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinQuotaExceededException(error.message ?: "Quota exceeded")
                }
                422 -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinApiException(
                        error.message ?: error.error,
                        response.status.value,
                        error.error
                    )
                }
                else -> {
                    val error: ErrorResponse = try {
                        response.body()
                    } catch (e: Exception) {
                        ErrorResponse("unknown_error", "HTTP ${response.status.value}")
                    }
                    throw ThelawinApiException(
                        error.message ?: error.error,
                        response.status.value,
                        error.error
                    )
                }
            }
        } catch (e: HttpRequestTimeoutException) {
            throw ThelawinNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is ThelawinException) throw e
            throw ThelawinNetworkException(e.message ?: "Unknown error", e)
        }
    }

    /**
     * Kontoinformationen abrufen (Quota, Plan, etc.)
     */
    suspend fun getAccount(): AccountInfo {
        return try {
            val response: HttpResponse = client.get("$apiUrl/v1/account") {
                header("X-API-Key", apiKey)
            }

            when (response.status.value) {
                200 -> response.body()
                401 -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinAuthException(error.message ?: "Unauthorized")
                }
                else -> {
                    val error: ErrorResponse = response.body()
                    throw ThelawinApiException(
                        error.message ?: error.error,
                        response.status.value,
                        error.error
                    )
                }
            }
        } catch (e: HttpRequestTimeoutException) {
            throw ThelawinNetworkException("Request timeout", e)
        } catch (e: Exception) {
            if (e is ThelawinException) throw e
            throw ThelawinNetworkException(e.message ?: "Unknown error", e)
        }
    }

    override fun close() {
        if (ownsClient) {
            client.close()
        }
    }
}
