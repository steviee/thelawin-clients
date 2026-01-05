package dev.envoice;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class EnvoiceClientTest {

    @Test
    void clientRequiresApiKey() {
        assertThrows(IllegalArgumentException.class, () -> new EnvoiceClient(""));
        assertThrows(IllegalArgumentException.class, () -> new EnvoiceClient(null));
        assertThrows(IllegalArgumentException.class, () -> new EnvoiceClient("   "));
    }

    @Test
    void clientCreatesWithValidApiKey() {
        try (var client = new EnvoiceClient("env_sandbox_test")) {
            assertNotNull(client);
        }
    }

    @Test
    void invoiceReturnsBuilder() {
        try (var client = new EnvoiceClient("env_sandbox_test")) {
            var builder = client.invoice();
            assertNotNull(builder);
            assertInstanceOf(InvoiceBuilder.class, builder);
        }
    }

    @Test
    void builderValidatesRequiredFields() {
        try (var client = new EnvoiceClient("env_sandbox_test")) {
            var result = client.invoice().generate();

            assertFalse(result.isSuccess());
            assertInstanceOf(InvoiceResult.Failure.class, result);

            var failure = (InvoiceResult.Failure) result;
            assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.number")));
            assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.date")));
            assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.seller")));
            assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.buyer")));
            assertTrue(failure.errors().stream().anyMatch(e -> e.path().equals("$.invoice.items")));
        }
    }

    @Test
    void builderFluentInterface() {
        try (var client = new EnvoiceClient("env_sandbox_test")) {
            var builder = client.invoice();

            assertSame(builder, builder.number("2026-001"));
            assertSame(builder, builder.date("2026-01-15"));
            assertSame(builder, builder.dueDate("2026-02-15"));
            assertSame(builder, builder.currency("EUR"));
            assertSame(builder, builder.template("minimal"));
            assertSame(builder, builder.locale("de"));
            assertSame(builder, builder.footerText("Thanks!"));
            assertSame(builder, builder.accentColor("#8b5cf6"));
        }
    }

    @Test
    void builderAcceptsPartyObjects() {
        try (var client = new EnvoiceClient("env_sandbox_test")) {
            var seller = Types.Party.builder("Acme GmbH")
                .vatId("DE123456789")
                .city("Berlin")
                .country("DE")
                .build();

            var buyer = Types.Party.builder("Customer AG")
                .city("München")
                .country("DE")
                .build();

            var builder = client.invoice()
                .seller(seller)
                .buyer(buyer);

            assertNotNull(builder);
        }
    }

    @Test
    void builderAcceptsLineItems() {
        try (var client = new EnvoiceClient("env_sandbox_test")) {
            var item = Types.LineItem.builder("Consulting")
                .quantity(8)
                .unit("HUR")
                .unitPrice(150.0)
                .vatRate(19.0)
                .build();

            var builder = client.invoice().addItem(item);
            assertNotNull(builder);
        }
    }

    @Test
    void successResultMethods() {
        var success = new InvoiceResult.Success(
            "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
            "invoice-2026-001.pdf",
            new Types.ValidationResult("valid", "EN16931", "2.3.2", null),
            new Types.AccountInfo(499, "starter", null, null, null)
        );

        assertTrue(success.isSuccess());
        assertEquals("invoice-2026-001.pdf", success.filename());
        assertEquals("EN16931", success.validation().profile());
        assertEquals(499, success.account().remaining());

        byte[] bytes = success.toBytes();
        assertTrue(bytes.length > 0);
        assertTrue(new String(bytes).startsWith("%PDF"));

        String dataUrl = success.toDataUrl();
        assertTrue(dataUrl.startsWith("data:application/pdf;base64,"));
    }

    @Test
    void failureResultMethods() {
        var failure = new InvoiceResult.Failure(List.of(
            new Types.ValidationError("$.invoice.number", "REQUIRED", "Invoice number is required", "error")
        ));

        assertFalse(failure.isSuccess());
        assertEquals(1, failure.errors().size());
        assertEquals("$.invoice.number", failure.errors().get(0).path());
    }
}
