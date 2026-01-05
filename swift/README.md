# Envoice Swift SDK

Official Swift SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

**Requires Swift 5.9+, iOS 15+, macOS 12+**

## Installation

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/steviee/envoice-clients.git", from: "0.1.0")
]
```

## Quick Start

```swift
import Envoice

let client = try EnvoiceClient(apiKey: "env_sandbox_xxx")

let result = try await client.invoice()
    .number("2026-001")
    .date("2026-01-15")
    .seller { party in
        party.name = "Acme GmbH"
        party.vatId = "DE123456789"
        party.street = "Hauptstraße 1"
        party.city = "Berlin"
        party.postalCode = "10115"
        party.country = "DE"
    }
    .buyer { party in
        party.name = "Customer AG"
        party.city = "München"
        party.country = "DE"
    }
    .addItem { item in
        item.description = "Consulting Services"
        item.quantity = 8
        item.unit = "HUR"
        item.unitPrice = 150.00
        item.vatRate = 19.0
    }
    .logoFile(URL(fileURLWithPath: "./logo.png"), widthMm: 30)
    .template("minimal")
    .generate()

switch result {
case .success(let invoice):
    try invoice.savePdf(to: URL(fileURLWithPath: "./invoices/2026-001.pdf"))
    print("Generated: \(invoice.filename)")
    print("Validation: \(invoice.validation.profile)")

case .failure(let errors):
    for error in errors {
        print("\(error.path): \(error.message)")
    }
}
```

## API Reference

### EnvoiceClient

```swift
let client = try EnvoiceClient(
    apiKey: "env_sandbox_xxx",
    apiUrl: "https://api.envoice.dev",  // optional
    timeout: 30                          // optional (seconds)
)
```

### InvoiceBuilder

```swift
client.invoice()
    .number(value)                    // Required
    .date(value)                      // String or Date, required
    .dueDate(value)                   // String or Date
    .seller(party)                    // Party or closure, required
    .buyer(party)                     // Party or closure, required
    .addItem(item)                    // LineItem or closure
    .payment(info)                    // PaymentInfo
    .currency(value)                  // Default: "EUR"
    .template("minimal" | "classic" | "compact")
    .locale(value)                    // "de", "en", "fr", "es", "it"
    .logoFile(url, widthMm:)
    .logoBase64(base64, widthMm:)
    .footerText(text)
    .accentColor(hex)
    .generate()                       // async throws
```

### Result Handling

```swift
switch result {
case .success(let invoice):
    try invoice.savePdf(to: url)
    let data = try invoice.toData()
    let dataUrl = invoice.toDataUrl()

case .failure(let errors):
    errors.forEach { print($0.message) }
}

// Or check directly
if result.isSuccess { ... }
```

## Error Handling

```swift
do {
    let result = try await client.invoice().number("001").generate()
    // ...
} catch EnvoiceError.quotaExceeded(let message) {
    print("Quota exceeded: \(message)")
} catch EnvoiceError.networkError(let message) {
    print("Network error: \(message)")
} catch EnvoiceError.apiError(let statusCode, let message, _) {
    print("API error \(statusCode): \(message)")
}
```

## License

MIT
