# Envoice Kotlin SDK

Official Kotlin SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

## Installation

### Gradle (Kotlin DSL)

```kotlin
dependencies {
    implementation("dev.envoice:sdk:0.1.0")
}
```

### Gradle (Groovy)

```groovy
dependencies {
    implementation 'dev.envoice:sdk:0.1.0'
}
```

### Maven

```xml
<dependency>
    <groupId>dev.envoice</groupId>
    <artifactId>sdk</artifactId>
    <version>0.1.0</version>
</dependency>
```

## Quick Start

```kotlin
import dev.envoice.*
import kotlinx.coroutines.runBlocking

fun main() = runBlocking {
    val client = EnvoiceClient("env_sandbox_xxx")

    val result = client.invoice()
        .number("2026-001")
        .date("2026-01-15")
        .seller {
            name = "Acme GmbH"
            vatId = "DE123456789"
            street = "Hauptstraße 1"
            city = "Berlin"
            postalCode = "10115"
            country = "DE"
        }
        .buyer {
            name = "Customer AG"
            city = "München"
            country = "DE"
        }
        .addItem {
            description = "Consulting Services"
            quantity = 8.0
            unit = "HUR"
            unitPrice = 150.00
            vatRate = 19.0
        }
        .logoFile("./logo.png", widthMm = 30)
        .template("minimal")
        .generate()

    when (result) {
        is InvoiceResult.Success -> {
            result.savePdf("./invoices/2026-001.pdf")
            println("Generated: ${result.filename}")
            println("Validation: ${result.validation.profile}")
        }
        is InvoiceResult.Failure -> {
            result.errors.forEach { error ->
                println("${error.path}: ${error.message}")
            }
        }
    }

    client.close()
}
```

## API Reference

### EnvoiceClient

```kotlin
val client = EnvoiceClient(
    apiKey = "env_sandbox_xxx",
    apiUrl = "https://api.envoice.dev",  // optional
    timeout = 30000L                      // optional (milliseconds)
)
```

### InvoiceBuilder

Fluent builder for creating invoices with Kotlin DSL:

```kotlin
client.invoice()
    .number(value)                    // Invoice number (required)
    .date(value)                      // String or LocalDate (required)
    .dueDate(value)                   // String or LocalDate
    .seller { ... }                   // DSL block (required)
    .buyer { ... }                    // DSL block (required)
    .addItem { ... }                  // DSL block (at least one required)
    .items(list)                      // Set all items at once
    .payment(iban, bic, terms, reference)
    .currency(value)                  // Default: "EUR"
    .template("minimal" | "classic" | "compact")
    .locale(value)                    // "de", "en", "fr", "es", "it"
    .logoFile(path, widthMm)
    .logoBase64(base64, widthMm)
    .footerText(text)
    .accentColor(hex)                 // e.g., "#8b5cf6"
    .generate()                       // suspend function
```

### DSL Builders

```kotlin
// Seller/Buyer DSL
seller {
    name = "Company Name"
    street = "Street Address"
    city = "City"
    postalCode = "12345"
    country = "DE"             // ISO 3166-1 alpha-2
    vatId = "DE123456789"
    email = "email@example.com"
    phone = "+49 30 12345678"
}

// Line Item DSL
addItem {
    description = "Service Description"
    quantity = 8.0
    unit = "HUR"               // UN/ECE Rec 20 code
    unitPrice = 150.00
    vatRate = 19.0
}
```

### Common Unit Codes

| Code | Description |
|------|-------------|
| `C62` | Piece (default) |
| `HUR` | Hour |
| `DAY` | Day |
| `MON` | Month |
| `KGM` | Kilogram |
| `MTR` | Meter |
| `LTR` | Liter |

### Result Handling

```kotlin
when (result) {
    is InvoiceResult.Success -> {
        result.savePdf("./invoice.pdf")
        val bytes = result.toBytes()
        val dataUrl = result.toDataUrl()
    }
    is InvoiceResult.Failure -> {
        result.errors.forEach { println(it.message) }
    }
}

// Or using extension properties
if (result.isSuccess) { ... }
if (result.isFailure) { ... }
```

### Direct API Methods

```kotlin
// Generate invoice directly (without builder)
val result = client.generateInvoice(request)

// Validate an existing PDF
val validation = client.validate(pdfBase64)

// Get account info (quota, plan)
val account = client.getAccount()
println("Remaining: ${account.remaining}")
```

## Error Handling

```kotlin
try {
    val result = client.invoice()
        .number("2026-001")
        .generate()

    if (result.isFailure) {
        // Validation errors (422)
        (result as InvoiceResult.Failure).errors.forEach {
            println("${it.path}: ${it.message}")
        }
    }
} catch (e: EnvoiceQuotaExceededException) {
    println("Quota exceeded, upgrade your plan")
} catch (e: EnvoiceNetworkException) {
    println("Network error: ${e.message}")
} catch (e: EnvoiceApiException) {
    println("API error ${e.statusCode}: ${e.message}")
}
```

## Resource Management

The client implements `Closeable`:

```kotlin
EnvoiceClient("env_sandbox_xxx").use { client ->
    val result = client.invoice()
        .number("2026-001")
        .generate()
}
```

## License

MIT
