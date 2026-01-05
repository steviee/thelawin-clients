# Envoice .NET SDK

Official .NET SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

**Requires .NET 8.0+**

## Installation

```bash
dotnet add package Envoice
```

## Quick Start

```csharp
using Envoice;

using var client = new EnvoiceClient("env_sandbox_xxx");

var result = await client.Invoice()
    .Number("2026-001")
    .Date("2026-01-15")
    .Seller(s => s
        .Name("Acme GmbH")
        .VatId("DE123456789")
        .Street("Hauptstraße 1")
        .City("Berlin")
        .PostalCode("10115")
        .Country("DE"))
    .Buyer(b => b
        .Name("Customer AG")
        .City("München")
        .Country("DE"))
    .AddItem(i => i
        .Description("Consulting Services")
        .Quantity(8)
        .Unit("HUR")
        .UnitPrice(150.00)
        .VatRate(19.0))
    .LogoFileAsync("./logo.png", widthMm: 30)
    .Result
    .Template("minimal")
    .GenerateAsync();

if (result.IsSuccess)
{
    var success = (InvoiceSuccess)result;
    await success.SavePdfAsync("./invoices/2026-001.pdf");
    Console.WriteLine($"Generated: {success.Filename}");
    Console.WriteLine($"Validation: {success.Validation.Profile}");
}
else
{
    var failure = (InvoiceFailure)result;
    foreach (var error in failure.Errors)
    {
        Console.Error.WriteLine($"{error.Path}: {error.Message}");
    }
}
```

## API Reference

### EnvoiceClient

```csharp
using var client = new EnvoiceClient(
    apiKey: "env_sandbox_xxx",
    apiUrl: "https://api.envoice.dev",  // optional
    timeout: TimeSpan.FromSeconds(30)   // optional
);
```

### InvoiceBuilder

```csharp
client.Invoice()
    .Number(value)                    // Required
    .Date(value)                      // String or DateOnly, required
    .DueDate(value)                   // String or DateOnly
    .Seller(s => s.Name(...).VatId(...))  // Required
    .Buyer(b => b.Name(...))          // Required
    .AddItem(i => i.Description(...).Quantity(...).UnitPrice(...))
    .Items(list)                      // Set all items
    .Payment(info)                    // PaymentInfo
    .Currency(value)                  // Default: "EUR"
    .Template("minimal" | "classic" | "compact")
    .Locale(value)                    // "de", "en", "fr", "es", "it"
    .LogoFileAsync(path, widthMm)     // async
    .LogoBase64(base64, widthMm)
    .FooterText(text)
    .AccentColor(hex)
    .GenerateAsync()                  // async
```

### Result Handling

```csharp
if (result.IsSuccess)
{
    var success = (InvoiceSuccess)result;
    await success.SavePdfAsync("./invoice.pdf");
    byte[] bytes = success.ToBytes();
    string dataUrl = success.ToDataUrl();
}
else
{
    var failure = (InvoiceFailure)result;
    foreach (var error in failure.Errors)
        Console.WriteLine(error.Message);
}

// Or with pattern matching
switch (result)
{
    case InvoiceSuccess success:
        await success.SavePdfAsync("./invoice.pdf");
        break;
    case InvoiceFailure failure:
        foreach (var error in failure.Errors)
            Console.Error.WriteLine(error.Message);
        break;
}
```

## Error Handling

```csharp
try
{
    var result = await client.Invoice().Number("001").GenerateAsync();
    // ...
}
catch (EnvoiceQuotaExceededException)
{
    Console.WriteLine("Quota exceeded, upgrade your plan");
}
catch (EnvoiceNetworkException ex)
{
    Console.WriteLine($"Network error: {ex.Message}");
}
catch (EnvoiceApiException ex)
{
    Console.WriteLine($"API error {ex.StatusCode}: {ex.Message}");
}
```

## License

MIT
