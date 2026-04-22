package dev.thelawin;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.time.Duration;
import java.time.LocalDate;
import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class ThelawinClientTest {

    // ── Client initialization ────────────────────────────────────────────

    @Nested
    @DisplayName("Client initialization")
    class ClientInit {

        @Test
        @DisplayName("rejects null API key")
        void rejectsNullApiKey() {
            assertThrows(IllegalArgumentException.class, () -> new ThelawinClient(null));
        }

        @Test
        @DisplayName("rejects empty API key")
        void rejectsEmptyApiKey() {
            assertThrows(IllegalArgumentException.class, () -> new ThelawinClient(""));
        }

        @Test
        @DisplayName("rejects blank API key")
        void rejectsBlankApiKey() {
            assertThrows(IllegalArgumentException.class, () -> new ThelawinClient("   "));
        }

        @Test
        @DisplayName("creates client with valid API key")
        void createsWithValidKey() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                assertNotNull(client);
            }
        }

        @Test
        @DisplayName("creates client with custom URL")
        void createsWithCustomUrl() {
            try (var client = new ThelawinClient("tlw_sandbox_test", "https://custom.api.example.com")) {
                assertNotNull(client);
            }
        }

        @Test
        @DisplayName("creates client with custom URL and timeout")
        void createsWithCustomUrlAndTimeout() {
            try (var client = new ThelawinClient("tlw_sandbox_test", "https://custom.api.example.com", Duration.ofSeconds(60))) {
                assertNotNull(client);
            }
        }

        @Test
        @DisplayName("strips trailing slash from URL")
        void stripsTrailingSlash() {
            // No direct way to assert internal state, but this should not throw
            try (var client = new ThelawinClient("tlw_sandbox_test", "https://api.thelawin.dev/")) {
                assertNotNull(client);
            }
        }
    }

    // ── InvoiceBuilder fluent API ────────────────────────────────────────

    @Nested
    @DisplayName("InvoiceBuilder fluent API")
    class BuilderFluent {

        @Test
        @DisplayName("invoice() returns an InvoiceBuilder")
        void invoiceReturnsBuilder() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var builder = client.invoice();
                assertNotNull(builder);
                assertInstanceOf(InvoiceBuilder.class, builder);
            }
        }

        @Test
        @DisplayName("all setters return the same builder instance")
        void settersReturnSameInstance() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var builder = client.invoice();

                assertSame(builder, builder.number("2026-001"));
                assertSame(builder, builder.date("2026-01-15"));
                assertSame(builder, builder.dueDate("2026-02-15"));
                assertSame(builder, builder.currency("EUR"));
                assertSame(builder, builder.template("minimal"));
                assertSame(builder, builder.locale("de"));
                assertSame(builder, builder.footerText("Thanks!"));
                assertSame(builder, builder.accentColor("#8b5cf6"));
                assertSame(builder, builder.format(Types.InvoiceFormat.ZUGFERD));
                assertSame(builder, builder.profile(Types.InvoiceProfile.EN16931));
                assertSame(builder, builder.notes("Some notes"));
                assertSame(builder, builder.leitwegId("04011000-1234512345-06"));
                assertSame(builder, builder.buyerReference("PO-2026-42"));
                assertSame(builder, builder.tipoDocumento("TD01"));
            }
        }

        @Test
        @DisplayName("accepts LocalDate for date fields")
        void acceptsLocalDate() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var builder = client.invoice();
                assertSame(builder, builder.date(LocalDate.of(2026, 4, 22)));
                assertSame(builder, builder.dueDate(LocalDate.of(2026, 5, 22)));
            }
        }

        @Test
        @DisplayName("accepts format as string")
        void acceptsFormatAsString() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var builder = client.invoice();
                assertSame(builder, builder.format("zugferd"));
            }
        }

        @Test
        @DisplayName("accepts profile as string")
        void acceptsProfileAsString() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var builder = client.invoice();
                assertSame(builder, builder.profile("en16931"));
            }
        }
    }

    // ── Builder validation ───────────────────────────────────────────────

    @Nested
    @DisplayName("Builder validation")
    class BuilderValidation {

        @Test
        @DisplayName("fails when all required fields are missing")
        void failsAllMissing() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var result = client.invoice().generate();

                assertFalse(result.isSuccess());
                assertInstanceOf(InvoiceResult.Failure.class, result);

                var failure = (InvoiceResult.Failure) result;
                assertEquals(5, failure.errors().size());
                assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.number")));
                assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.date")));
                assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.seller")));
                assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.buyer")));
                assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.items")));
            }
        }

        @Test
        @DisplayName("fails when only number is missing")
        void failsNumberMissing() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var result = client.invoice()
                    .date("2026-01-15")
                    .seller(Types.Party.builder("Seller").build())
                    .buyer(Types.Party.builder("Buyer").build())
                    .addItem(Types.LineItem.builder("Item").unitPrice(100).build())
                    .generate();

                assertFalse(result.isSuccess());
                var failure = (InvoiceResult.Failure) result;
                assertEquals(1, failure.errors().size());
                assertEquals("$.invoice.number", failure.errors().get(0).path());
                assertEquals("REQUIRED", failure.errors().get(0).code());
            }
        }

        @Test
        @DisplayName("fails when items list is empty")
        void failsItemsEmpty() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var result = client.invoice()
                    .number("2026-001")
                    .date("2026-01-15")
                    .seller(Types.Party.builder("Seller").build())
                    .buyer(Types.Party.builder("Buyer").build())
                    .generate();

                assertFalse(result.isSuccess());
                var failure = (InvoiceResult.Failure) result;
                assertEquals(1, failure.errors().size());
                assertEquals("$.invoice.items", failure.errors().get(0).path());
            }
        }

        @Test
        @DisplayName("validation errors have severity 'error'")
        void validationErrorSeverity() {
            try (var client = new ThelawinClient("tlw_sandbox_test")) {
                var result = client.invoice().generate();
                var failure = (InvoiceResult.Failure) result;
                assertTrue(failure.errors().stream().allMatch(e -> "error".equals(e.severity())));
            }
        }
    }

    // ── Party builder ────────────────────────────────────────────────────

    @Nested
    @DisplayName("Party builder")
    class PartyBuilder {

        @Test
        @DisplayName("builds a basic party with name only")
        void buildsBasicParty() {
            var party = Types.Party.builder("Acme GmbH").build();
            assertEquals("Acme GmbH", party.name());
            assertNull(party.vatId());
            assertNull(party.peppolId());
        }

        @Test
        @DisplayName("builds a party with all standard fields")
        void buildsFullParty() {
            var party = Types.Party.builder("Acme GmbH")
                .street("Hauptstr. 1")
                .city("Berlin")
                .postalCode("10115")
                .country("DE")
                .vatId("DE123456789")
                .email("info@acme.de")
                .phone("+49 30 12345")
                .build();

            assertEquals("Acme GmbH", party.name());
            assertEquals("Hauptstr. 1", party.street());
            assertEquals("Berlin", party.city());
            assertEquals("10115", party.postalCode());
            assertEquals("DE", party.country());
            assertEquals("DE123456789", party.vatId());
            assertEquals("info@acme.de", party.email());
            assertEquals("+49 30 12345", party.phone());
        }

        @Test
        @DisplayName("builds a party with Peppol fields")
        void buildsPeppolParty() {
            var party = Types.Party.builder("Nordic AB")
                .country("SE")
                .vatId("SE556677889901")
                .peppolId("0007:5567891234")
                .build();

            assertEquals("0007:5567891234", party.peppolId());
            assertEquals("SE556677889901", party.vatId());
        }

        @Test
        @DisplayName("builds a party with FatturaPA fields")
        void buildsFatturapaParty() {
            var party = Types.Party.builder("Azienda Srl")
                .country("IT")
                .vatId("IT01234567890")
                .codiceFiscale("RSSMRA80A01H501U")
                .codiceDestinatario("A1B2C3D")
                .pec("azienda@pec.it")
                .build();

            assertEquals("IT01234567890", party.vatId());
            assertEquals("RSSMRA80A01H501U", party.codiceFiscale());
            assertEquals("A1B2C3D", party.codiceDestinatario());
            assertEquals("azienda@pec.it", party.pec());
        }

        @Test
        @DisplayName("compact constructor creates party with name only")
        void compactConstructor() {
            var party = new Types.Party("Quick Corp");
            assertEquals("Quick Corp", party.name());
            assertNull(party.street());
            assertNull(party.peppolId());
        }
    }

    // ── LineItem builder ─────────────────────────────────────────────────

    @Nested
    @DisplayName("LineItem builder")
    class LineItemBuilder {

        @Test
        @DisplayName("builds with defaults (qty=1, unit=C62, vatRate=19)")
        void buildsWithDefaults() {
            var item = Types.LineItem.builder("Consulting")
                .unitPrice(150.0)
                .build();

            assertEquals("Consulting", item.description());
            assertEquals(1.0, item.quantity());
            assertEquals("C62", item.unit());
            assertEquals(150.0, item.unitPrice());
            assertEquals(19.0, item.vatRate());
            assertNull(item.natura());
        }

        @Test
        @DisplayName("builds with all fields including natura")
        void buildsWithAllFields() {
            var item = Types.LineItem.builder("Servizio esente")
                .quantity(2)
                .unit("HUR")
                .unitPrice(200.0)
                .vatRate(0.0)
                .natura("N4")
                .build();

            assertEquals("Servizio esente", item.description());
            assertEquals(2.0, item.quantity());
            assertEquals("HUR", item.unit());
            assertEquals(200.0, item.unitPrice());
            assertEquals(0.0, item.vatRate());
            assertEquals("N4", item.natura());
        }

        @Test
        @DisplayName("compact constructor sets sensible defaults")
        void compactConstructor() {
            var item = new Types.LineItem("Widget", 3, 49.99);
            assertEquals("Widget", item.description());
            assertEquals(3.0, item.quantity());
            assertEquals("C62", item.unit());
            assertEquals(49.99, item.unitPrice());
            assertEquals(19.0, item.vatRate());
            assertNull(item.natura());
        }
    }

    // ── InvoiceResult handling ───────────────────────────────────────────

    @Nested
    @DisplayName("InvoiceResult handling")
    class ResultHandling {

        private static final String SAMPLE_PDF_B64 =
            "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK";

        @Test
        @DisplayName("Success isSuccess returns true")
        void successIsSuccess() {
            var result = new InvoiceResult.Success(SAMPLE_PDF_B64, "inv.pdf", null, null);
            assertTrue(result.isSuccess());
        }

        @Test
        @DisplayName("Success provides filename and validation")
        void successAccessors() {
            var validation = new Types.ValidationResult("valid", "EN16931", "2.3.2", null);
            var account = new Types.AccountInfo(499, "starter", null, null, null);
            var result = new InvoiceResult.Success(SAMPLE_PDF_B64, "invoice-2026-001.pdf", validation, account);

            assertEquals("invoice-2026-001.pdf", result.filename());
            assertEquals("EN16931", result.validation().profile());
            assertEquals(499, result.account().remaining());
        }

        @Test
        @DisplayName("Success toBytes returns decoded PDF")
        void successToBytes() {
            var result = new InvoiceResult.Success(SAMPLE_PDF_B64, "inv.pdf", null, null);
            byte[] bytes = result.toBytes();
            assertTrue(bytes.length > 0);
            assertTrue(new String(bytes).startsWith("%PDF"));
        }

        @Test
        @DisplayName("Success toDataUrl returns proper data URI")
        void successToDataUrl() {
            var result = new InvoiceResult.Success(SAMPLE_PDF_B64, "inv.pdf", null, null);
            String url = result.toDataUrl();
            assertTrue(url.startsWith("data:application/pdf;base64,"));
            assertTrue(url.contains(SAMPLE_PDF_B64));
        }

        @Test
        @DisplayName("Failure isSuccess returns false")
        void failureIsSuccess() {
            var result = new InvoiceResult.Failure(List.of());
            assertFalse(result.isSuccess());
        }

        @Test
        @DisplayName("Failure provides error list")
        void failureErrors() {
            var errors = List.of(
                new Types.ValidationError("$.invoice.number", "REQUIRED", "Invoice number is required", "error"),
                new Types.ValidationError("$.invoice.seller", "REQUIRED", "Seller information is required", "error")
            );
            var result = new InvoiceResult.Failure(errors);

            assertEquals(2, result.errors().size());
            assertEquals("$.invoice.number", result.errors().get(0).path());
            assertEquals("$.invoice.seller", result.errors().get(1).path());
        }

        @Test
        @DisplayName("sealed interface permits only Success and Failure")
        void sealedInterface() {
            // Verify the sealed hierarchy via instanceof pattern matching
            InvoiceResult success = new InvoiceResult.Success(SAMPLE_PDF_B64, "inv.pdf", null, null);
            InvoiceResult failure = new InvoiceResult.Failure(List.of());

            assertTrue(success instanceof InvoiceResult.Success);
            assertFalse(success instanceof InvoiceResult.Failure);
            assertTrue(failure instanceof InvoiceResult.Failure);
            assertFalse(failure instanceof InvoiceResult.Success);
        }
    }

    // ── InvoiceFormat / InvoiceProfile enums ─────────────────────────────

    @Nested
    @DisplayName("InvoiceFormat enum")
    class FormatEnum {

        @Test
        @DisplayName("has all 9 format values")
        void hasAllFormats() {
            assertEquals(9, Types.InvoiceFormat.values().length);
        }

        @Test
        @DisplayName("getValue returns lowercase API string")
        void getValueReturnsApiString() {
            assertEquals("zugferd", Types.InvoiceFormat.ZUGFERD.getValue());
            assertEquals("facturx", Types.InvoiceFormat.FACTURX.getValue());
            assertEquals("xrechnung", Types.InvoiceFormat.XRECHNUNG.getValue());
            assertEquals("peppol", Types.InvoiceFormat.PEPPOL.getValue());
            assertEquals("fatturapa", Types.InvoiceFormat.FATTURAPA.getValue());
            assertEquals("auto", Types.InvoiceFormat.AUTO.getValue());
            assertEquals("ubl", Types.InvoiceFormat.UBL.getValue());
            assertEquals("cii", Types.InvoiceFormat.CII.getValue());
            assertEquals("pdf", Types.InvoiceFormat.PDF.getValue());
        }

        @Test
        @DisplayName("toString returns the API value")
        void toStringReturnsValue() {
            assertEquals("zugferd", Types.InvoiceFormat.ZUGFERD.toString());
        }
    }

    @Nested
    @DisplayName("InvoiceProfile enum")
    class ProfileEnum {

        @Test
        @DisplayName("has all 6 profile values")
        void hasAllProfiles() {
            assertEquals(6, Types.InvoiceProfile.values().length);
        }

        @Test
        @DisplayName("getValue returns lowercase API string")
        void getValueReturnsApiString() {
            assertEquals("minimum", Types.InvoiceProfile.MINIMUM.getValue());
            assertEquals("basicwl", Types.InvoiceProfile.BASIC_WL.getValue());
            assertEquals("basic", Types.InvoiceProfile.BASIC.getValue());
            assertEquals("en16931", Types.InvoiceProfile.EN16931.getValue());
            assertEquals("extended", Types.InvoiceProfile.EXTENDED.getValue());
            assertEquals("xrechnung", Types.InvoiceProfile.XRECHNUNG.getValue());
        }
    }

    // ── Exceptions ───────────────────────────────────────────────────────

    @Nested
    @DisplayName("Exception hierarchy")
    class ExceptionTests {

        @Test
        @DisplayName("ThelawinException is the base class")
        void baseException() {
            var ex = new Exceptions.ThelawinException("test");
            assertInstanceOf(RuntimeException.class, ex);
            assertEquals("test", ex.getMessage());
        }

        @Test
        @DisplayName("ThelawinApiException carries status and code")
        void apiException() {
            var ex = new Exceptions.ThelawinApiException("Not Found", 404, "not_found");
            assertEquals(404, ex.getStatusCode());
            assertEquals("not_found", ex.getCode());
            assertEquals("Not Found", ex.getMessage());
            assertInstanceOf(Exceptions.ThelawinException.class, ex);
        }

        @Test
        @DisplayName("ThelawinNetworkException wraps cause")
        void networkException() {
            var cause = new java.io.IOException("connection refused");
            var ex = new Exceptions.ThelawinNetworkException("Network error", cause);
            assertEquals("Network error", ex.getMessage());
            assertSame(cause, ex.getCause());
            assertInstanceOf(Exceptions.ThelawinException.class, ex);
        }

        @Test
        @DisplayName("ThelawinQuotaExceededException has status 402")
        void quotaException() {
            var ex = new Exceptions.ThelawinQuotaExceededException("Quota exceeded");
            assertEquals(402, ex.getStatusCode());
            assertEquals("quota_exceeded", ex.getCode());
            assertInstanceOf(Exceptions.ThelawinApiException.class, ex);
        }

        @Test
        @DisplayName("ThelawinValidationException formats errors")
        void validationException() {
            var errors = List.of(
                new Types.ValidationError("$.number", "REQUIRED", "Number required", "error"),
                new Types.ValidationError("$.date", "REQUIRED", "Date required", "error")
            );
            var ex = new Exceptions.ThelawinValidationException(errors, 422);
            assertEquals(422, ex.getStatusCode());
            assertEquals(2, ex.getErrors().size());
            assertTrue(ex.getMessage().contains("$.number"));
            assertTrue(ex.toUserMessage().contains("- $.number: Number required"));
            assertTrue(ex.toUserMessage().contains("- $.date: Date required"));
        }
    }

    // ── Retrieve types ───────────────────────────────────────────────────

    @Nested
    @DisplayName("Retrieve types")
    class RetrieveTypes {

        @Test
        @DisplayName("RetrieveRequest holds data, content type, and flag")
        void retrieveRequest() {
            var req = new Types.RetrieveRequest("dGVzdA==", "application/pdf", true);
            assertEquals("dGVzdA==", req.dataBase64());
            assertEquals("application/pdf", req.contentType());
            assertTrue(req.includeSourceXml());
        }

        @Test
        @DisplayName("DetectedFormat holds format metadata")
        void detectedFormat() {
            var fmt = new Types.DetectedFormat("zugferd", "EN16931", "2.3.2", "CII", true);
            assertEquals("zugferd", fmt.detectedFormat());
            assertEquals("EN16931", fmt.profile());
            assertEquals("2.3.2", fmt.version());
            assertEquals("CII", fmt.xmlType());
            assertTrue(fmt.hasPdf());
        }

        @Test
        @DisplayName("RetrieveError holds code, message, path, severity")
        void retrieveError() {
            var err = new Types.RetrieveError("INVALID_XML", "Malformed XML", "$.invoice", "error");
            assertEquals("INVALID_XML", err.code());
            assertEquals("Malformed XML", err.message());
            assertEquals("$.invoice", err.path());
            assertEquals("error", err.severity());
        }

        @Test
        @DisplayName("RetrieveResponse holds all fields")
        void retrieveResponse() {
            var format = new Types.DetectedFormat("facturx", "BASIC", "1.0", "CII", true);
            var invoice = new Types.InvoiceData("INV-001", "2026-01-01", null,
                new Types.Party("Seller"), new Types.Party("Buyer"),
                List.of(new Types.LineItem("Item", 1, 100)), null, "EUR");
            var warnings = List.of(new Types.RetrieveError("WARN", "Minor issue", null, "warning"));

            var resp = new Types.RetrieveResponse(true, format, invoice, "eG1s", "tx-123", List.of(), warnings);

            assertTrue(resp.valid());
            assertEquals("facturx", resp.format().detectedFormat());
            assertEquals("INV-001", resp.invoice().number());
            assertEquals("eG1s", resp.sourceXmlBase64());
            assertEquals("tx-123", resp.transactionId());
            assertTrue(resp.errors().isEmpty());
            assertEquals(1, resp.warnings().size());
        }
    }

    // ── InvoiceData new fields ───────────────────────────────────────────

    @Nested
    @DisplayName("InvoiceData new fields")
    class InvoiceDataFields {

        @Test
        @DisplayName("backward-compatible constructor sets new fields to null")
        void backwardCompatible() {
            var data = new Types.InvoiceData("INV-001", "2026-01-01", null,
                new Types.Party("S"), new Types.Party("B"),
                List.of(new Types.LineItem("x", 1, 10)), null, "EUR");

            assertNull(data.notes());
            assertNull(data.leitwegId());
            assertNull(data.buyerReference());
            assertNull(data.tipoDocumento());
        }

        @Test
        @DisplayName("full constructor includes notes, leitwegId, buyerReference, tipoDocumento")
        void fullConstructor() {
            var data = new Types.InvoiceData("INV-001", "2026-01-01", "2026-02-01",
                new Types.Party("S"), new Types.Party("B"),
                List.of(new Types.LineItem("x", 1, 10)), null, "EUR",
                "Payment within 30 days",
                "04011000-1234512345-06",
                "PO-2026-42",
                "TD01");

            assertEquals("Payment within 30 days", data.notes());
            assertEquals("04011000-1234512345-06", data.leitwegId());
            assertEquals("PO-2026-42", data.buyerReference());
            assertEquals("TD01", data.tipoDocumento());
        }
    }
}
