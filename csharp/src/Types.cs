using System.Text.Json.Serialization;

namespace Thelawin;

/// <summary>Supported invoice output formats</summary>
[JsonConverter(typeof(JsonStringEnumConverter<InvoiceFormat>))]
public enum InvoiceFormat
{
    /// <summary>Auto-detect based on country and fields</summary>
    [JsonPropertyName("auto")] Auto,
    /// <summary>ZUGFeRD 2.4 (PDF/A-3 + CII XML, Germany)</summary>
    [JsonPropertyName("zugferd")] Zugferd,
    /// <summary>Factur-X 1.0.8 (PDF/A-3 + CII XML, France)</summary>
    [JsonPropertyName("facturx")] Facturx,
    /// <summary>XRechnung 3.0.2 (PDF/A-3 + UBL XML, German B2G)</summary>
    [JsonPropertyName("xrechnung")] Xrechnung,
    /// <summary>UBL 2.1 Invoice (XML only, OASIS standard)</summary>
    [JsonPropertyName("ubl")] Ubl,
    /// <summary>UN/CEFACT CII (XML only)</summary>
    [JsonPropertyName("cii")] Cii,
    /// <summary>Peppol BIS Billing 3.0 (XML only, UBL-based)</summary>
    [JsonPropertyName("peppol")] Peppol,
    /// <summary>FatturaPA 1.2.2 (XML only, Italian SDI)</summary>
    [JsonPropertyName("fatturapa")] Fatturapa,
    /// <summary>Plain PDF without XML</summary>
    [JsonPropertyName("pdf")] Pdf
}

/// <summary>ZUGFeRD/Factur-X conformance profiles</summary>
[JsonConverter(typeof(JsonStringEnumConverter<InvoiceProfile>))]
public enum InvoiceProfile
{
    [JsonPropertyName("minimum")] Minimum,
    [JsonPropertyName("basic_wl")] BasicWl,
    [JsonPropertyName("basic")] Basic,
    [JsonPropertyName("en16931")] En16931,
    [JsonPropertyName("extended")] Extended,
    [JsonPropertyName("xrechnung")] Xrechnung
}

/// <summary>Party (seller or buyer) information</summary>
public record Party(
    string Name,
    string? Street = null,
    string? City = null,
    [property: JsonPropertyName("postalCode")] string? PostalCode = null,
    string? Country = null,
    [property: JsonPropertyName("vatId")] string? VatId = null,
    string? Email = null,
    string? Phone = null,
    [property: JsonPropertyName("endpointId")] string? EndpointId = null,
    [property: JsonPropertyName("endpointScheme")] string? EndpointScheme = null,
    [property: JsonPropertyName("codiceFiscale")] string? CodiceFiscale = null,
    [property: JsonPropertyName("codiceDestinatario")] string? CodiceDestinatario = null,
    [property: JsonPropertyName("pecEmail")] string? PecEmail = null
);

/// <summary>Line item in an invoice</summary>
public record LineItem(
    string Description,
    double Quantity,
    string Unit = "C62",
    [property: JsonPropertyName("unitPrice")] double UnitPrice = 0,
    [property: JsonPropertyName("vatRate")] double VatRate = 19.0,
    string? Natura = null
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
    string Currency = "EUR",
    string? Notes = null,
    [property: JsonPropertyName("leitwegId")] string? LeitwegId = null,
    [property: JsonPropertyName("buyerReference")] string? BuyerReference = null,
    [property: JsonPropertyName("tipoDocumento")] string? TipoDocumento = null
);

/// <summary>Generate request</summary>
public record GenerateRequest(
    string Template,
    string Locale,
    InvoiceData Invoice,
    Customization? Customization = null,
    [property: JsonPropertyName("format")] InvoiceFormat? Format = null,
    [property: JsonPropertyName("profile")] InvoiceProfile? Profile = null
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

/// <summary>Detected format from a retrieved document</summary>
public record DetectedFormat(
    string Format,
    string? Profile = null,
    string? Version = null
);

/// <summary>Error detail from a retrieve operation</summary>
public record RetrieveError(
    string Code,
    string Message
);

/// <summary>Response from the /v1/retrieve endpoint</summary>
public record RetrieveResponse(
    bool Success,
    [property: JsonPropertyName("detectedFormat")] DetectedFormat? DetectedFormat = null,
    InvoiceData? Invoice = null,
    [property: JsonPropertyName("sourceXml")] string? SourceXml = null,
    List<RetrieveError>? Errors = null,
    AccountInfo? Account = null
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
