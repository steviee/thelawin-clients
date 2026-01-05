using System.Text.Json.Serialization;

namespace Envoice;

/// <summary>Party (seller or buyer) information</summary>
public record Party(
    string Name,
    string? Street = null,
    string? City = null,
    [property: JsonPropertyName("postalCode")] string? PostalCode = null,
    string? Country = null,
    [property: JsonPropertyName("vatId")] string? VatId = null,
    string? Email = null,
    string? Phone = null
);

/// <summary>Line item in an invoice</summary>
public record LineItem(
    string Description,
    double Quantity,
    string Unit = "C62",
    [property: JsonPropertyName("unitPrice")] double UnitPrice = 0,
    [property: JsonPropertyName("vatRate")] double VatRate = 19.0
);

/// <summary>Payment information</summary>
public record PaymentInfo(
    string? Iban = null,
    string? Bic = null,
    string? Terms = null,
    string? Reference = null
);

/// <summary>Customization options</summary>
public record Customization(
    [property: JsonPropertyName("logoBase64")] string? LogoBase64 = null,
    [property: JsonPropertyName("logoWidthMm")] int? LogoWidthMm = null,
    [property: JsonPropertyName("footerText")] string? FooterText = null,
    [property: JsonPropertyName("accentColor")] string? AccentColor = null
);

/// <summary>Invoice data</summary>
public record InvoiceData(
    string Number,
    string Date,
    [property: JsonPropertyName("dueDate")] string? DueDate,
    Party Seller,
    Party Buyer,
    List<LineItem> Items,
    PaymentInfo? Payment = null,
    string Currency = "EUR"
);

/// <summary>Generate request</summary>
public record GenerateRequest(
    string Template,
    string Locale,
    InvoiceData Invoice,
    Customization? Customization = null
);

/// <summary>Validation result</summary>
public record ValidationResult(
    string Status,
    string Profile,
    string Version,
    List<string>? Warnings = null
);

/// <summary>Account info</summary>
public record AccountInfo(
    int Remaining,
    string Plan,
    [property: JsonPropertyName("overageCount")] int? OverageCount = null,
    [property: JsonPropertyName("overageAllowed")] int? OverageAllowed = null,
    string? Warning = null
);

/// <summary>Validation error</summary>
public record ValidationError(
    string Path,
    string Code,
    string Message,
    string? Severity = "error"
);

internal record GenerateResponse(
    [property: JsonPropertyName("pdf_base64")] string PdfBase64,
    string Filename,
    ValidationResult Validation,
    AccountInfo? Account = null
);

internal record ErrorResponse(
    string Error,
    string? Message = null,
    List<ValidationError>? Details = null
);
