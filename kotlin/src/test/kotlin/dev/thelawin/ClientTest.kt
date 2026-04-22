package dev.thelawin

import io.ktor.client.*
import io.ktor.client.engine.mock.*
import io.ktor.client.plugins.contentnegotiation.*
import io.ktor.client.request.*
import io.ktor.http.*
import io.ktor.serialization.kotlinx.json.*
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDate
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
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

    private fun jsonHeaders() = headersOf(HttpHeaders.ContentType, "application/json")

    // ---------------------------------------------------------------
    // Client Init
    // ---------------------------------------------------------------

    @Test
    fun `client requires non-blank API key`() {
        assertThrows<IllegalArgumentException> {
            ThelawinClient("")
        }
    }

    @Test
    fun `client requires non-whitespace API key`() {
        assertThrows<IllegalArgumentException> {
            ThelawinClient("   ")
        }
    }

    @Test
    fun `client creates with valid API key`() {
        val client = ThelawinClient("env_sandbox_test")
        client.close()
    }

    @Test
    fun `client uses default base URL`() = runTest {
        val mockClient = createMockClient { request ->
            assertTrue(request.url.toString().startsWith("https://api.thelawin.dev"))
            respond("{}", HttpStatusCode.OK, jsonHeaders())
        }

        // Kein Zugriff auf die interne URL, daher testen wir ueber den Mock indirekt
        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)
        client.close()
    }

    @Test
    fun `client uses custom base URL`() = runTest {
        var capturedUrl = ""
        val mockClient = createMockClient { request ->
            capturedUrl = request.url.toString()
            respond(
                content = """{"remaining": 100, "plan": "sandbox"}""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", apiUrl = "https://custom.api.dev", httpClient = mockClient)
        client.getAccount()
        assertTrue(capturedUrl.startsWith("https://custom.api.dev"))
        client.close()
    }

    @Test
    fun `client sends API key header`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("env_sandbox_mykey", request.headers["X-API-Key"])
            respond(
                content = """{"remaining": 100, "plan": "sandbox"}""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_mykey", httpClient = mockClient)
        client.getAccount()
        client.close()
    }

    // ---------------------------------------------------------------
    // InvoiceBuilder Fluent API
    // ---------------------------------------------------------------

    @Test
    fun `invoice returns builder`() {
        val client = ThelawinClient("env_sandbox_test")
        val builder = client.invoice()
        assertTrue(builder is InvoiceBuilder)
        client.close()
    }

    @Test
    fun `builder supports all fluent methods`() = runTest {
        val mockClient = createMockClient { request ->
            val body = request.body.toByteArray().decodeToString()
            assertTrue(body.contains("\"number\":\"2026-042\""))
            assertTrue(body.contains("\"format\":\"xrechnung\""))
            assertTrue(body.contains("\"profile\":\"en16931\""))
            assertTrue(body.contains("\"notes\":\"Testnotiz\""))
            assertTrue(body.contains("\"leitwegId\":\"04011000-1234512345-12\""))
            assertTrue(body.contains("\"buyerReference\":\"REF-001\""))
            assertTrue(body.contains("\"tipoDocumento\":\"TD01\""))
            assertTrue(body.contains("\"currency\":\"USD\""))
            assertTrue(body.contains("\"template\":\"professional\""))
            assertTrue(body.contains("\"locale\":\"de\""))

            respond(
                content = """{
                    "pdf_base64": "JVBER",
                    "filename": "invoice-2026-042.pdf",
                    "validation": {"status": "valid", "profile": "EN16931", "version": "2.4"}
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)
        val result = client.invoice()
            .number("2026-042")
            .date("2026-04-22")
            .dueDate("2026-05-22")
            .format(InvoiceFormat.XRECHNUNG)
            .profile(InvoiceProfile.EN16931)
            .notes("Testnotiz")
            .leitwegId("04011000-1234512345-12")
            .buyerReference("REF-001")
            .tipoDocumento("TD01")
            .currency("USD")
            .template("professional")
            .locale("de")
            .seller {
                name = "Acme GmbH"
                vatId = "DE123456789"
                street = "Hauptstr. 1"
                city = "Berlin"
                postalCode = "10115"
                country = "DE"
                email = "billing@acme.de"
                phone = "+49 30 12345"
                peppolId = "0204:DE123456789"
            }
            .buyer {
                name = "Customer AG"
                city = "Muenchen"
                country = "DE"
                codiceDestinatario = "0000000"
                codiceFiscale = "RSSMRA85M01H501Z"
                pec = "customer@pec.it"
            }
            .addItem {
                description = "Consulting"
                quantity = 8.0
                unitPrice = 150.0
                vatRate = 19.0
            }
            .addItem {
                description = "Esente IVA"
                quantity = 1.0
                unitPrice = 100.0
                vatRate = 0.0
                natura = "N4"
            }
            .payment(iban = "DE89370400440532013000", bic = "COBADEFFXXX", terms = "Net 30")
            .footerText("Vielen Dank!")
            .accentColor("#7c3aed")
            .generate()

        assertTrue(result.isSuccess)
        client.close()
    }

    @Test
    fun `builder date from LocalDate`() = runTest {
        val mockClient = createMockClient { request ->
            val body = request.body.toByteArray().decodeToString()
            assertTrue(body.contains("\"date\":\"2026-04-22\""))
            assertTrue(body.contains("\"dueDate\":\"2026-05-22\""))

            respond(
                content = """{
                    "pdf_base64": "JVBER",
                    "filename": "test.pdf",
                    "validation": {"status": "valid", "profile": "EN16931", "version": "2.4"}
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)
        client.invoice()
            .number("LD-001")
            .date(LocalDate.of(2026, 4, 22))
            .dueDate(LocalDate.of(2026, 5, 22))
            .seller { name = "Seller" }
            .buyer { name = "Buyer" }
            .addItem { description = "Item"; unitPrice = 10.0 }
            .generate()

        client.close()
    }

    @Test
    fun `builder items replaces all items`() = runTest {
        val mockClient = createMockClient { request ->
            val body = request.body.toByteArray().decodeToString()
            // Sollte nur die 2 items aus items() enthalten, nicht das per addItem hinzugefuegte
            assertFalse(body.contains("\"description\":\"Old\""))
            assertTrue(body.contains("\"description\":\"New A\""))
            assertTrue(body.contains("\"description\":\"New B\""))

            respond(
                content = """{
                    "pdf_base64": "JVBER",
                    "filename": "test.pdf",
                    "validation": {"status": "valid", "profile": "BASIC", "version": "2.4"}
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)
        client.invoice()
            .number("ITEMS-001")
            .date("2026-01-01")
            .seller { name = "S" }
            .buyer { name = "B" }
            .addItem { description = "Old"; unitPrice = 1.0 }
            .items(listOf(
                LineItem(description = "New A", quantity = 1.0, unitPrice = 50.0),
                LineItem(description = "New B", quantity = 2.0, unitPrice = 25.0)
            ))
            .generate()

        client.close()
    }

    @Test
    fun `builder seller from Party object`() {
        val client = ThelawinClient("env_sandbox_test")
        val party = Party(name = "Direct Party", city = "Hamburg", country = "DE")
        val builder = client.invoice().seller(party)
        assertTrue(builder is InvoiceBuilder)
        client.close()
    }

    @Test
    fun `builder buyer from Party object`() {
        val client = ThelawinClient("env_sandbox_test")
        val party = Party(name = "Direct Buyer", city = "Hamburg")
        val builder = client.invoice().buyer(party)
        assertTrue(builder is InvoiceBuilder)
        client.close()
    }

    @Test
    fun `builder payment from PaymentInfo object`() {
        val client = ThelawinClient("env_sandbox_test")
        val payment = PaymentInfo(iban = "DE89370400440532013000")
        val builder = client.invoice().payment(payment)
        assertTrue(builder is InvoiceBuilder)
        client.close()
    }

    @Test
    fun `builder addItem from LineItem object`() {
        val client = ThelawinClient("env_sandbox_test")
        val item = LineItem(description = "Widget", quantity = 5.0, unitPrice = 9.99)
        val builder = client.invoice().addItem(item)
        assertTrue(builder is InvoiceBuilder)
        client.close()
    }

    // ---------------------------------------------------------------
    // Generate: success, validation error 422, quota 402, auth 401, server 500, timeout
    // ---------------------------------------------------------------

    @Test
    fun `generate success returns InvoiceResult Success`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("/v1/generate", request.url.encodedPath)

            respond(
                content = """{
                    "pdf_base64": "JVBERi0xLjQK...",
                    "filename": "invoice-2026-001.pdf",
                    "validation": {
                        "status": "valid",
                        "profile": "EN16931",
                        "version": "2.4",
                        "warnings": ["Minor: field X is recommended"]
                    },
                    "account": {
                        "remaining": 499,
                        "plan": "starter"
                    }
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val result = client.invoice()
            .number("2026-001")
            .date("2026-01-15")
            .seller { name = "Acme GmbH"; vatId = "DE123456789"; city = "Berlin"; country = "DE" }
            .buyer { name = "Customer AG"; city = "Muenchen"; country = "DE" }
            .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
            .generate()

        assertTrue(result.isSuccess)
        assertFalse(result.isFailure)
        val success = result as InvoiceResult.Success
        assertEquals("JVBERi0xLjQK...", success.pdfBase64)
        assertEquals("invoice-2026-001.pdf", success.filename)
        assertEquals("EN16931", success.validation.profile)
        assertEquals("valid", success.validation.status)
        assertEquals("2.4", success.validation.version)
        assertNotNull(success.validation.warnings)
        assertEquals(1, success.validation.warnings!!.size)
        assertEquals(499, success.account?.remaining)
        assertEquals("starter", success.account?.plan)

        // Utility-Methoden testen
        assertTrue(success.toDataUrl().startsWith("data:application/pdf;base64,"))

        client.close()
    }

    @Test
    fun `generate validation error 422 returns Failure`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "error": "validation_error",
                    "message": "Validation failed",
                    "details": [
                        {
                            "path": "$.invoice.seller.vatId",
                            "code": "INVALID_FORMAT",
                            "message": "Invalid VAT ID format",
                            "severity": "error"
                        },
                        {
                            "path": "$.invoice.buyer.name",
                            "code": "REQUIRED",
                            "message": "Buyer name is required",
                            "severity": "error"
                        }
                    ]
                }""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val result = client.invoice()
            .number("2026-001")
            .date("2026-01-15")
            .seller { name = "Acme GmbH"; vatId = "INVALID" }
            .buyer { name = "" }
            .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
            .generate()

        assertTrue(result.isFailure)
        assertFalse(result.isSuccess)
        val failure = result as InvoiceResult.Failure
        assertEquals(2, failure.errors.size)
        assertEquals("$.invoice.seller.vatId", failure.errors[0].path)
        assertEquals("INVALID_FORMAT", failure.errors[0].code)
        assertEquals("error", failure.errors[0].severity)
        assertEquals("$.invoice.buyer.name", failure.errors[1].path)

        client.close()
    }

    @Test
    fun `generate 422 without details throws ApiException`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "error": "unprocessable_entity",
                    "message": "Request body malformed"
                }""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val exception = assertThrows<ThelawinApiException> {
            client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller { name = "Acme GmbH" }
                .buyer { name = "Customer AG" }
                .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
                .generate()
        }

        assertEquals(422, exception.statusCode)
        assertEquals("unprocessable_entity", exception.code)

        client.close()
    }

    @Test
    fun `generate quota exceeded 402 throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "error": "quota_exceeded",
                    "message": "Monthly quota exceeded. Upgrade at https://thelawin.dev/billing"
                }""",
                status = HttpStatusCode.PaymentRequired,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val exception = assertThrows<ThelawinQuotaExceededException> {
            client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller { name = "Acme GmbH"; vatId = "DE123456789" }
                .buyer { name = "Customer AG" }
                .addItem { description = "Consulting"; quantity = 8.0; unitPrice = 150.0 }
                .generate()
        }

        assertEquals(402, exception.statusCode)
        assertEquals("quota_exceeded", exception.code)
        assertTrue(exception.message!!.contains("Monthly quota exceeded"))

        client.close()
    }

    @Test
    fun `generate auth error 401 throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "error": "unauthorized",
                    "message": "Invalid API key"
                }""",
                status = HttpStatusCode.Unauthorized,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_invalid", httpClient = mockClient)

        val exception = assertThrows<ThelawinAuthException> {
            client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller { name = "Acme GmbH" }
                .buyer { name = "Customer AG" }
                .addItem { description = "Test"; quantity = 1.0; unitPrice = 100.0 }
                .generate()
        }

        assertEquals(401, exception.statusCode)
        assertTrue(exception.message!!.contains("Invalid API key"))

        client.close()
    }

    @Test
    fun `generate server error 500 throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "error": "internal_error",
                    "message": "Internal server error"
                }""",
                status = HttpStatusCode.InternalServerError,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val exception = assertThrows<ThelawinApiException> {
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
    fun `generate missing fields returns client-side Failure`() = runTest {
        val client = ThelawinClient("env_sandbox_test")

        val result = client.invoice().generate()

        assertTrue(result.isFailure)
        val failure = result as InvoiceResult.Failure
        assertEquals(5, failure.errors.size)
        assertTrue(failure.errors.any { it.path == "$.invoice.number" && it.code == "REQUIRED" })
        assertTrue(failure.errors.any { it.path == "$.invoice.date" && it.code == "REQUIRED" })
        assertTrue(failure.errors.any { it.path == "$.invoice.seller" && it.code == "REQUIRED" })
        assertTrue(failure.errors.any { it.path == "$.invoice.buyer" && it.code == "REQUIRED" })
        assertTrue(failure.errors.any { it.path == "$.invoice.items" && it.code == "REQUIRED" })

        client.close()
    }

    @Test
    fun `generate with non-JSON error response throws ApiException`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = "Bad Gateway",
                status = HttpStatusCode.BadGateway,
                headers = headersOf(HttpHeaders.ContentType, "text/plain")
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        assertThrows<ThelawinException> {
            client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller { name = "Acme GmbH" }
                .buyer { name = "Customer AG" }
                .addItem { description = "Test"; quantity = 1.0; unitPrice = 100.0 }
                .generate()
        }

        client.close()
    }

    // ---------------------------------------------------------------
    // Validate: valid, invalid
    // ---------------------------------------------------------------

    @Test
    fun `validate returns valid response`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("/v1/validate", request.url.encodedPath)
            assertEquals(ContentType.Application.Json, request.body.contentType)

            respond(
                content = """{
                    "valid": true,
                    "profile": "EN16931",
                    "format": "zugferd"
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val invoiceData = InvoiceData(
            number = "VAL-001",
            date = "2026-01-15",
            seller = Party(name = "Acme GmbH", vatId = "DE123456789"),
            buyer = Party(name = "Customer AG"),
            items = listOf(LineItem(description = "Test", quantity = 1.0, unitPrice = 100.0))
        )
        val result = client.validate(ValidateRequest(invoice = invoiceData))

        assertTrue(result.valid)
        assertEquals("EN16931", result.profile)
        assertEquals("zugferd", result.format)
        assertNull(result.errors)

        client.close()
    }

    @Test
    fun `validate returns invalid with errors`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "valid": false,
                    "errors": [
                        {"path": "$.invoice.seller.vatId", "code": "MISSING", "message": "VAT ID is required for ZUGFeRD"},
                        {"path": "$.invoice.items[0].vatRate", "code": "INVALID", "message": "VAT rate must be >= 0"}
                    ],
                    "warnings": [
                        {"path": "$.invoice.dueDate", "code": "RECOMMENDED", "message": "Due date is recommended", "severity": "warning"}
                    ]
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val invoiceData = InvoiceData(
            number = "VAL-002",
            date = "2026-01-15",
            seller = Party(name = "Acme GmbH"),
            buyer = Party(name = "Customer AG"),
            items = listOf(LineItem(description = "Test", quantity = 1.0, unitPrice = 100.0, vatRate = -1.0))
        )
        val result = client.validate(ValidateRequest(invoice = invoiceData, format = InvoiceFormat.ZUGFERD))

        assertFalse(result.valid)
        assertNotNull(result.errors)
        assertEquals(2, result.errors!!.size)
        assertEquals("$.invoice.seller.vatId", result.errors!![0].path)
        assertNotNull(result.warnings)
        assertEquals(1, result.warnings!!.size)
        assertEquals("warning", result.warnings!![0].severity)

        client.close()
    }

    @Test
    fun `validate auth error 401 throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{"error": "unauthorized", "message": "Invalid API key"}""",
                status = HttpStatusCode.Unauthorized,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_invalid", httpClient = mockClient)

        assertThrows<ThelawinAuthException> {
            val invoiceData = InvoiceData(
                number = "VAL-003",
                date = "2026-01-15",
                seller = Party(name = "S"),
                buyer = Party(name = "B"),
                items = listOf(LineItem(description = "T", quantity = 1.0, unitPrice = 1.0))
            )
            client.validate(ValidateRequest(invoice = invoiceData))
        }

        client.close()
    }

    // ---------------------------------------------------------------
    // Retrieve: PDF extraction, XML extraction, source XML, invalid file, quota 402
    // ---------------------------------------------------------------

    @Test
    fun `retrieve extracts invoice from PDF`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("/v1/retrieve", request.url.encodedPath)
            val body = request.body.toByteArray().decodeToString()
            assertTrue(body.contains("\"data_base64\""))
            assertTrue(body.contains("\"content_type\":\"application/pdf\""))

            respond(
                content = """{
                    "valid": true,
                    "format": {
                        "detected_format": "zugferd",
                        "profile": "EN16931",
                        "version": "2.4",
                        "xml_type": "CII",
                        "has_pdf": true
                    },
                    "invoice": {
                        "number": "RE-2026-001",
                        "date": "2026-01-15",
                        "seller": {"name": "Acme GmbH", "vatId": "DE123456789"},
                        "buyer": {"name": "Customer AG"},
                        "items": [{"description": "Consulting", "quantity": 8.0, "unitPrice": 150.0}],
                        "currency": "EUR"
                    },
                    "transaction_id": "txn_abc123"
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val result = client.retrieve(
            dataBase64 = "JVBERi0xLjQKMSAwIG9iago=",
            contentType = "application/pdf"
        )

        assertTrue(result.valid)
        assertNotNull(result.format)
        assertEquals("zugferd", result.format!!.detectedFormat)
        assertEquals("EN16931", result.format!!.profile)
        assertEquals("2.4", result.format!!.version)
        assertEquals("CII", result.format!!.xmlType)
        assertTrue(result.format!!.hasPdf)
        assertNotNull(result.invoice)
        assertEquals("RE-2026-001", result.invoice!!.number)
        assertEquals("Acme GmbH", result.invoice!!.seller.name)
        assertEquals("DE123456789", result.invoice!!.seller.vatId)
        assertEquals(1, result.invoice!!.items.size)
        assertEquals(150.0, result.invoice!!.items[0].unitPrice)
        assertEquals("txn_abc123", result.transactionId)
        assertNull(result.sourceXmlBase64)

        client.close()
    }

    @Test
    fun `retrieve extracts invoice from XML`() = runTest {
        val mockClient = createMockClient { request ->
            val body = request.body.toByteArray().decodeToString()
            assertTrue(body.contains("\"content_type\":\"application/xml\""))

            respond(
                content = """{
                    "valid": true,
                    "format": {
                        "detected_format": "xrechnung",
                        "profile": "EN16931",
                        "version": "3.0.2",
                        "xml_type": "UBL",
                        "has_pdf": false
                    },
                    "invoice": {
                        "number": "XR-2026-001",
                        "date": "2026-04-01",
                        "seller": {"name": "Amt GmbH"},
                        "buyer": {"name": "Behoerde"},
                        "items": [{"description": "Dienstleistung", "quantity": 1.0, "unitPrice": 500.0}],
                        "leitwegId": "04011000-1234512345-12",
                        "buyerReference": "BR-001"
                    },
                    "transaction_id": "txn_xml456"
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val result = client.retrieve(
            dataBase64 = "PD94bWwgdmVyc2lvbj0iMS4wIj8+",
            contentType = "application/xml"
        )

        assertTrue(result.valid)
        assertNotNull(result.format)
        assertEquals("xrechnung", result.format!!.detectedFormat)
        assertEquals("UBL", result.format!!.xmlType)
        assertFalse(result.format!!.hasPdf)
        assertNotNull(result.invoice)
        assertEquals("XR-2026-001", result.invoice!!.number)
        assertEquals("04011000-1234512345-12", result.invoice!!.leitwegId)
        assertEquals("BR-001", result.invoice!!.buyerReference)

        client.close()
    }

    @Test
    fun `retrieve with source XML`() = runTest {
        val mockClient = createMockClient { request ->
            val body = request.body.toByteArray().decodeToString()
            assertTrue(body.contains("\"include_source_xml\":true"))

            respond(
                content = """{
                    "valid": true,
                    "format": {
                        "detected_format": "facturx",
                        "profile": "BASIC",
                        "version": "1.0.8",
                        "xml_type": "CII",
                        "has_pdf": true
                    },
                    "invoice": {
                        "number": "FX-001",
                        "date": "2026-03-01",
                        "seller": {"name": "French Co"},
                        "buyer": {"name": "Acheteur"},
                        "items": [{"description": "Service", "quantity": 1.0, "unitPrice": 200.0}]
                    },
                    "source_xml_base64": "PD94bWwgdmVyc2lvbj0iMS4wIj8+PENyb3NzSW5kdXN0cnlJbnZvaWNlPjwvQ3Jvc3NJbmR1c3RyeUludm9pY2U+",
                    "transaction_id": "txn_src789"
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val result = client.retrieve(
            dataBase64 = "JVBERi0xLjQK",
            includeSourceXml = true
        )

        assertTrue(result.valid)
        assertNotNull(result.sourceXmlBase64)
        assertTrue(result.sourceXmlBase64!!.isNotBlank())
        assertEquals("facturx", result.format!!.detectedFormat)

        client.close()
    }

    @Test
    fun `retrieve with auto-detected content type`() = runTest {
        val mockClient = createMockClient { request ->
            val body = request.body.toByteArray().decodeToString()
            // content_type sollte null / nicht gesendet sein
            assertFalse(body.contains("\"content_type\":\"application"))

            respond(
                content = """{
                    "valid": true,
                    "format": {"detected_format": "zugferd", "has_pdf": true},
                    "invoice": {
                        "number": "AUTO-001",
                        "date": "2026-01-01",
                        "seller": {"name": "S"},
                        "buyer": {"name": "B"},
                        "items": [{"description": "X", "quantity": 1.0, "unitPrice": 1.0}]
                    },
                    "transaction_id": "txn_auto"
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)
        val result = client.retrieve(dataBase64 = "JVBERi0xLjQK")

        assertTrue(result.valid)
        assertEquals("AUTO-001", result.invoice!!.number)

        client.close()
    }

    @Test
    fun `retrieve invalid file returns 422`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "error": "invalid_file",
                    "message": "Could not parse the provided file. Supported: PDF/A-3 with ZUGFeRD/Factur-X XML, or standalone UBL/CII XML."
                }""",
                status = HttpStatusCode.UnprocessableEntity,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val exception = assertThrows<ThelawinApiException> {
            client.retrieve(dataBase64 = "bm90LWEtcGRm")
        }

        assertEquals(422, exception.statusCode)
        assertTrue(exception.message!!.contains("Could not parse"))

        client.close()
    }

    @Test
    fun `retrieve quota exceeded 402 throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{"error": "quota_exceeded", "message": "Monthly quota exceeded"}""",
                status = HttpStatusCode.PaymentRequired,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val exception = assertThrows<ThelawinQuotaExceededException> {
            client.retrieve(dataBase64 = "JVBERi0xLjQK")
        }

        assertEquals(402, exception.statusCode)

        client.close()
    }

    @Test
    fun `retrieve auth error 401 throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{"error": "unauthorized", "message": "Invalid API key"}""",
                status = HttpStatusCode.Unauthorized,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_bad", httpClient = mockClient)

        assertThrows<ThelawinAuthException> {
            client.retrieve(dataBase64 = "JVBERi0xLjQK")
        }

        client.close()
    }

    // ---------------------------------------------------------------
    // Account: success, sandbox, unauthorized
    // ---------------------------------------------------------------

    @Test
    fun `getAccount returns account info for paid plan`() = runTest {
        val mockClient = createMockClient { request ->
            assertEquals("/v1/account", request.url.encodedPath)

            respond(
                content = """{
                    "remaining": 450,
                    "plan": "starter",
                    "overageCount": 5,
                    "overageAllowed": 75
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_live_test", httpClient = mockClient)

        val account = client.getAccount()

        assertEquals("starter", account.plan)
        assertEquals(450, account.remaining)
        assertEquals(5, account.overageCount)
        assertEquals(75, account.overageAllowed)
        assertNull(account.warning)

        client.close()
    }

    @Test
    fun `getAccount returns sandbox info with warning`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "remaining": 12,
                    "plan": "sandbox",
                    "warning": "Low credits remaining. Upgrade at https://thelawin.dev/billing"
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val account = client.getAccount()

        assertEquals("sandbox", account.plan)
        assertEquals(12, account.remaining)
        assertNotNull(account.warning)
        assertTrue(account.warning!!.contains("Low credits"))

        client.close()
    }

    @Test
    fun `getAccount unauthorized throws exception`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{"error": "unauthorized", "message": "Invalid API key"}""",
                status = HttpStatusCode.Unauthorized,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_bad", httpClient = mockClient)

        assertThrows<ThelawinAuthException> {
            client.getAccount()
        }

        client.close()
    }

    // ---------------------------------------------------------------
    // Edge Cases & Enum Serialization
    // ---------------------------------------------------------------

    @Test
    fun `InvoiceFormat enum serializes correctly`() {
        val json = Json { encodeDefaults = true }
        val formats = InvoiceFormat.entries.map { json.encodeToString(InvoiceFormat.serializer(), it) }

        assertTrue(formats.contains("\"auto\""))
        assertTrue(formats.contains("\"zugferd\""))
        assertTrue(formats.contains("\"facturx\""))
        assertTrue(formats.contains("\"xrechnung\""))
        assertTrue(formats.contains("\"ubl\""))
        assertTrue(formats.contains("\"cii\""))
        assertTrue(formats.contains("\"peppol\""))
        assertTrue(formats.contains("\"fatturapa\""))
        assertTrue(formats.contains("\"pdf\""))
    }

    @Test
    fun `InvoiceProfile enum serializes correctly`() {
        val json = Json { encodeDefaults = true }
        val profiles = InvoiceProfile.entries.map { json.encodeToString(InvoiceProfile.serializer(), it) }

        assertTrue(profiles.contains("\"minimum\""))
        assertTrue(profiles.contains("\"basic_wl\""))
        assertTrue(profiles.contains("\"basic\""))
        assertTrue(profiles.contains("\"en16931\""))
        assertTrue(profiles.contains("\"extended\""))
    }

    @Test
    fun `ThelawinValidationException provides user-friendly message`() {
        val errors = listOf(
            ValidationError("$.invoice.number", "REQUIRED", "Invoice number is required"),
            ValidationError("$.invoice.seller.vatId", "INVALID_FORMAT", "Invalid VAT ID")
        )
        val exception = ThelawinValidationException(errors)

        assertTrue(exception.toUserMessage().contains("$.invoice.number"))
        assertTrue(exception.toUserMessage().contains("$.invoice.seller.vatId"))
        assertEquals(422, exception.statusCode)
    }

    @Test
    fun `generateInvoice direct call works`() = runTest {
        val mockClient = createMockClient { request ->
            respond(
                content = """{
                    "pdf_base64": "JVBER",
                    "filename": "direct.pdf",
                    "validation": {"status": "valid", "profile": "BASIC", "version": "2.4"}
                }""",
                status = HttpStatusCode.OK,
                headers = jsonHeaders()
            )
        }

        val client = ThelawinClient("env_sandbox_test", httpClient = mockClient)

        val request = GenerateRequest(
            invoice = InvoiceData(
                number = "DIRECT-001",
                date = "2026-01-01",
                seller = Party(name = "Seller"),
                buyer = Party(name = "Buyer"),
                items = listOf(LineItem(description = "Item", quantity = 1.0, unitPrice = 50.0))
            )
        )

        val result = client.generateInvoice(request)
        assertTrue(result.isSuccess)
        assertEquals("direct.pdf", (result as InvoiceResult.Success).filename)

        client.close()
    }
}
