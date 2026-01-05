package dev.envoice

import io.ktor.client.*
import io.ktor.client.engine.mock.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ClientTest {

    private val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = false
    }

    private fun createMockClient(handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData): HttpClient {
        return HttpClient(MockEngine) {
            engine {
                addHandler(handler)
            }
            install(ContentNegotiation) {
                json(json)
            }
        }
    }

    @Test
    fun `client requires API key`() {
        assertThrows<IllegalArgumentException> {
            EnvoiceClient("")
        }
    }

    @Test
    fun `client creates with valid API key`() {
        val client = EnvoiceClient("env_sandbox_test")
        client.close()
    }

    @Test
    fun `invoice returns builder`() {
        val client = EnvoiceClient("env_sandbox_test")
        val builder = client.invoice()
        assertTrue(builder is InvoiceBuilder)
        client.close()
    }

    @Test
    fun `successful generation returns Success`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("/v1/generate", request.url.encodedPath)
            assertEquals("env_sandbox_test", request.headers["X-API-Key"])

            respond(
                content = """
                    {
                        "pdf_base64": "JVBERi0xLjQK...",
                        "filename": "invoice-2026-001.pdf",
                        "validation": {
                            "status": "valid",
                            "profile": "EN16931",
                            "version": "2.3.2"
                        },
                        "account": {
                            "remaining": 499,
                            "plan": "starter"
                        }
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = EnvoiceClient("env_sandbox_test", httpClient = mockClient)

        val result = client.invoice()
            .number("2026-001")
            .date("2026-01-15")
            .seller { name = "Acme GmbH"; vatId = "DE123456789"; city = "Berlin"; country = "DE" }
            .buyer { name = "Customer AG"; city = "München"; country = "DE" }
            .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
            .generate()

        assertTrue(result.isSuccess)
        val success = result as InvoiceResult.Success
        assertEquals("JVBERi0xLjQK...", success.pdfBase64)
        assertEquals("invoice-2026-001.pdf", success.filename)
        assertEquals("EN16931", success.validation.profile)
        assertEquals(499, success.account?.remaining)

        client.close()
    }

    @Test
    fun `validation errors return Failure`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """
                    {
                        "error": "validation_error",
                        "message": "Validation failed",
                        "details": [
                            {
                                "path": "$.invoice.seller.vatId",
                                "code": "INVALID_FORMAT",
                                "message": "Invalid VAT ID format"
                            }
                        ]
                    }
                """.trimIndent(),
                status = HttpStatusCode.UnprocessableEntity,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = EnvoiceClient("env_sandbox_test", httpClient = mockClient)

        val result = client.invoice()
            .number("2026-001")
            .date("2026-01-15")
            .seller { name = "Acme GmbH"; vatId = "INVALID"; city = "Berlin"; country = "DE" }
            .buyer { name = "Customer AG" }
            .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
            .generate()

        assertTrue(result.isFailure)
        val failure = result as InvoiceResult.Failure
        assertEquals(1, failure.errors.size)
        assertEquals("$.invoice.seller.vatId", failure.errors[0].path)
        assertEquals("INVALID_FORMAT", failure.errors[0].code)

        client.close()
    }

    @Test
    fun `quota exceeded throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """
                    {
                        "error": "quota_exceeded",
                        "message": "Monthly quota exceeded"
                    }
                """.trimIndent(),
                status = HttpStatusCode.PaymentRequired,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = EnvoiceClient("env_sandbox_test", httpClient = mockClient)

        assertThrows<EnvoiceQuotaExceededException> {
            client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller { name = "Acme GmbH"; vatId = "DE123456789" }
                .buyer { name = "Customer AG" }
                .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
                .generate()
        }

        client.close()
    }

    @Test
    fun `API error throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """
                    {
                        "error": "internal_error",
                        "message": "Internal server error"
                    }
                """.trimIndent(),
                status = HttpStatusCode.InternalServerError,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = EnvoiceClient("env_sandbox_test", httpClient = mockClient)

        val exception = assertThrows<EnvoiceApiException> {
            client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller { name = "Acme GmbH"; vatId = "DE123456789" }
                .buyer { name = "Customer AG" }
                .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
                .generate()
        }

        assertEquals(500, exception.statusCode)
        assertEquals("internal_error", exception.code)

        client.close()
    }

    @Test
    fun `missing required fields returns Failure`() = runTest {
        val client = EnvoiceClient("env_sandbox_test")

        val result = client.invoice().generate()

        assertTrue(result.isFailure)
        val failure = result as InvoiceResult.Failure
        assertTrue(failure.errors.any { it.path == "$.invoice.number" })
        assertTrue(failure.errors.any { it.path == "$.invoice.date" })
        assertTrue(failure.errors.any { it.path == "$.invoice.seller" })
        assertTrue(failure.errors.any { it.path == "$.invoice.buyer" })
        assertTrue(failure.errors.any { it.path == "$.invoice.items" })

        client.close()
    }

    @Test
    fun `getAccount returns account info`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("/v1/account", request.url.encodedPath)

            respond(
                content = """
                    {
                        "plan": "starter",
                        "remaining": 450,
                        "used": 50,
                        "limit": 500
                    }
                """.trimIndent(),
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json")
            )
        }

        val client = EnvoiceClient("env_sandbox_test", httpClient = mockClient)

        val account = client.getAccount()

        assertEquals("starter", account.plan)
        assertEquals(450, account.remaining)

        client.close()
    }
}
