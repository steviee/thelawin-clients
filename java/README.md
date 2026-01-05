# Envoice Java SDK

Official Java SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

**Requires Java 17+**

## Installation

### Maven

```xml
<dependency>
    <groupId>dev.envoice</groupId>
    <artifactId>sdk</artifactId>
    <version>0.1.0</version>
</dependency>
```

### Gradle

```groovy
implementation 'dev.envoice:sdk:0.1.0'
```

## Quick Start

```java
import dev.envoice.*;

public class Example {
    public static void main(String[] args) throws Exception {
        try (var client = new EnvoiceClient("env_sandbox_xxx")) {
            var result = client.invoice()
                .number("2026-001")
                .date("2026-01-15")
                .seller(s -> s
                    .name("Acme GmbH")
                    .vatId("DE123456789")
                    .street("Hauptstraße 1")
                    .city("Berlin")
                    .postalCode("10115")
                    .country("DE"))
                .buyer(b -> b
                    .name("Customer AG")
                    .city("München")
                    .country("DE"))
                .addItem(i -> i
                    .description("Consulting Services")
                    .quantity(8)
                    .unit("HUR")
                    .unitPrice(150.00)
                    .vatRate(19.0))
                .logoFile(Path.of("./logo.png"), 30)
                .template("minimal")
                .generate();

            if (result.isSuccess()) {
                var success = (InvoiceResult.Success) result;
                success.savePdf("./invoices/2026-001.pdf");
                System.out.println("Generated: " + success.filename());
                System.out.println("Validation: " + success.validation().profile());
            } else {
                var failure = (InvoiceResult.Failure) result;
                failure.errors().forEach(error ->
                    System.err.println(error.path() + ": " + error.message()));
            }
        }
    }
}
```

## API Reference

### EnvoiceClient

```java
var client = new EnvoiceClient("env_sandbox_xxx");

// With custom options
var client = new EnvoiceClient(
    "env_sandbox_xxx",
    "https://api.envoice.dev",
    Duration.ofSeconds(30)
);
```

### InvoiceBuilder

```java
client.invoice()
    .number(value)                    // Required
    .date(value)                      // String or LocalDate, required
    .dueDate(value)                   // String or LocalDate
    .seller(configurator)             // Lambda or Party, required
    .buyer(configurator)              // Lambda or Party, required
    .addItem(configurator)            // Lambda or LineItem, at least one
    .items(list)                      // Set all items at once
    .payment(info)                    // PaymentInfo
    .currency(value)                  // Default: "EUR"
    .template("minimal" | "classic" | "compact")
    .locale(value)                    // "de", "en", "fr", "es", "it"
    .logoFile(path, widthMm)
    .logoBase64(base64, widthMm)
    .footerText(text)
    .accentColor(hex)
    .generate()
```

### Result Handling

```java
if (result.isSuccess()) {
    var success = (InvoiceResult.Success) result;
    success.savePdf("./invoice.pdf");
    byte[] bytes = success.toBytes();
    String dataUrl = success.toDataUrl();
} else {
    var failure = (InvoiceResult.Failure) result;
    failure.errors().forEach(e -> System.out.println(e.message()));
}
```

### Pattern Matching (Java 21+)

```java
switch (result) {
    case InvoiceResult.Success s -> {
        s.savePdf("./invoice.pdf");
        System.out.println("Generated: " + s.filename());
    }
    case InvoiceResult.Failure f -> {
        f.errors().forEach(e -> System.err.println(e.message()));
    }
}
```

## Error Handling

```java
try {
    var result = client.invoice().number("001").generate();
    // ...
} catch (Exceptions.EnvoiceQuotaExceededException e) {
    System.out.println("Quota exceeded");
} catch (Exceptions.EnvoiceNetworkException e) {
    System.out.println("Network error: " + e.getMessage());
} catch (Exceptions.EnvoiceApiException e) {
    System.out.println("API error " + e.getStatusCode() + ": " + e.getMessage());
}
```

## License

MIT
