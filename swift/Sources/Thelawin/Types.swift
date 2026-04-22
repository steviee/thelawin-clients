import Foundation

// MARK: - Enums

/// Output format for invoice generation
public enum InvoiceFormat: String, Codable, Sendable {
    case auto
    case zugferd
    case facturx
    case xrechnung
    case pdf
    case ubl
    case cii
    case peppol
    case fatturapa

    /// Whether this format produces XML only (no visual PDF)
    public var isXmlOnly: Bool {
        switch self {
        case .ubl, .cii, .peppol, .fatturapa:
            return true
        default:
            return false
        }
    }

    /// Whether this format embeds XML in a PDF/A-3
    public var isPdfWithXml: Bool {
        switch self {
        case .zugferd, .facturx, .xrechnung:
            return true
        default:
            return false
        }
    }
}

/// Profile for ZUGFeRD/Factur-X formats
public enum InvoiceProfile: String, Codable, Sendable {
    case minimum
    case basicWl = "basic_wl"
    case basic
    case en16931
    case extended
}

// MARK: - Party

/// Party (seller or buyer) information.
/// Supports format-specific fields for Peppol and FatturaPA.
public struct Party: Codable, Sendable {
    public var name: String
    public var street: String?
    public var city: String?
    public var postalCode: String?
    public var country: String?
    public var vatId: String?
    public var email: String?
    public var phone: String?
    /// Peppol participant ID (format: "EAS:ID", e.g., "0088:1234567890123")
    public var peppolId: String?
    /// Italian tax code (FatturaPA)
    public var codiceFiscale: String?
    /// Italian SDI recipient code (FatturaPA, 7 chars or "0000000")
    public var codiceDestinatario: String?
    /// Italian certified email (FatturaPA)
    public var pec: String?

    public init(
        name: String,
        street: String? = nil,
        city: String? = nil,
        postalCode: String? = nil,
        country: String? = nil,
        vatId: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        peppolId: String? = nil,
        codiceFiscale: String? = nil,
        codiceDestinatario: String? = nil,
        pec: String? = nil
    ) {
        self.name = name
        self.street = street
        self.city = city
        self.postalCode = postalCode
        self.country = country
        self.vatId = vatId
        self.email = email
        self.phone = phone
        self.peppolId = peppolId
        self.codiceFiscale = codiceFiscale
        self.codiceDestinatario = codiceDestinatario
        self.pec = pec
    }
}

// MARK: - Line Item

/// Line item in an invoice.
/// Supports format-specific fields for FatturaPA.
public struct LineItem: Codable, Sendable {
    public var description: String
    public var quantity: Double
    public var unit: String
    public var unitPrice: Double
    public var vatRate: Double
    /// FatturaPA VAT exemption code (N1-N7, e.g., "N2.2" for non-taxable)
    public var natura: String?

    public init(
        description: String,
        quantity: Double,
        unit: String = "C62",
        unitPrice: Double,
        vatRate: Double = 19.0,
        natura: String? = nil
    ) {
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.vatRate = vatRate
        self.natura = natura
    }
}

// MARK: - Payment

/// Payment information
public struct PaymentInfo: Codable, Sendable {
    public var iban: String?
    public var bic: String?
    public var terms: String?
    public var reference: String?

    public init(iban: String? = nil, bic: String? = nil, terms: String? = nil, reference: String? = nil) {
        self.iban = iban
        self.bic = bic
        self.terms = terms
        self.reference = reference
    }
}

// MARK: - Customization

/// Customization options for the invoice PDF
public struct Customization: Codable, Sendable {
    public var logoBase64: String?
    public var logoWidthMm: Int?
    public var footerText: String?
    public var accentColor: String?

    public init(
        logoBase64: String? = nil,
        logoWidthMm: Int? = nil,
        footerText: String? = nil,
        accentColor: String? = nil
    ) {
        self.logoBase64 = logoBase64
        self.logoWidthMm = logoWidthMm
        self.footerText = footerText
        self.accentColor = accentColor
    }

    /// Whether any customization has been set
    public var isEmpty: Bool {
        logoBase64 == nil && footerText == nil && accentColor == nil
    }
}

// MARK: - Invoice Data

/// Invoice data sent in a generate or validate request
public struct InvoiceData: Codable, Sendable {
    public var number: String
    public var date: String
    public var dueDate: String?
    public var seller: Party
    public var buyer: Party
    public var items: [LineItem]
    public var payment: PaymentInfo?
    public var currency: String
    /// Invoice notes/comments
    public var notes: String?
    /// Leitweg-ID for XRechnung (German B2G)
    public var leitwegId: String?
    /// Buyer reference for Peppol
    public var buyerReference: String?
    /// Document type for FatturaPA (e.g., "TD01", "TD04")
    public var tipoDocumento: String?
}

// MARK: - Request / Response

/// Generate request payload
public struct GenerateRequest: Codable, Sendable {
    public var format: String
    public var profile: String
    public var template: String
    public var locale: String
    public var invoice: InvoiceData
    public var customization: Customization?
}

// MARK: - Legal Warning

/// Legal warning from format detection
public struct LegalWarning: Codable, Sendable {
    public var code: String
    public var message: String
    public var legalBasis: String?
    public var severity: String?

    /// Whether this is an informational message
    public var isInfo: Bool { severity == "info" }

    /// Whether this is a warning
    public var isWarning: Bool { severity == "warning" || severity == nil }
}

// MARK: - Format Info

/// Format information from the API response
public struct FormatInfo: Codable, Sendable {
    public var formatUsed: String
    public var profile: String?
    public var version: String?
    public var formatReason: String?
    public var warnings: [LegalWarning]?

    /// Whether this format embeds XML in a PDF/A-3
    public var isPdfWithXml: Bool {
        ["zugferd", "facturx", "xrechnung"].contains(formatUsed)
    }

    /// Whether this format is XML-only (no visual PDF)
    public var isXmlOnly: Bool {
        ["ubl", "cii", "peppol", "fatturapa"].contains(formatUsed)
    }

    /// Whether this format is plain PDF (no XML)
    public var isPlainPdf: Bool {
        formatUsed == "pdf"
    }
}

// MARK: - Detected Format (for retrieve)

/// Detected format from the retrieve endpoint
public struct DetectedFormat: Codable, Sendable {
    public var format: String
    public var profile: String?
    public var version: String?
}

// MARK: - Validation

/// Validation result embedded in a generate response
public struct ValidationResult: Codable, Sendable {
    public var status: String
    public var profile: String
    public var version: String
    public var warnings: [String]?
}

/// Validation error detail
public struct ValidationError: Codable, Sendable, Equatable {
    public var path: String
    public var code: String
    public var message: String
    public var severity: String?

    public init(path: String, code: String, message: String, severity: String? = nil) {
        self.path = path
        self.code = code
        self.message = message
        self.severity = severity
    }
}

// MARK: - Account

/// Account information from the API
public struct AccountInfo: Codable, Sendable {
    public var remaining: Int
    public var plan: String
    public var overageCount: Int?
    public var overageAllowed: Int?
    public var warning: String?
}

// MARK: - Retrieve

/// Request body for the retrieve endpoint
struct RetrieveRequest: Codable {
    var dataBase64: String
    var contentType: String?
    var includeSourceXml: Bool?

    enum CodingKeys: String, CodingKey {
        case dataBase64 = "data_base64"
        case contentType = "content_type"
        case includeSourceXml = "include_source_xml"
    }
}

/// Error detail from the retrieve endpoint
public struct RetrieveError: Codable, Sendable {
    public var code: String
    public var message: String
}

/// Response from the retrieve endpoint
public struct RetrieveResponse: Codable, Sendable {
    public var success: Bool
    public var format: DetectedFormat?
    public var invoice: RetrievedInvoiceData?
    public var sourceXml: String?
    public var errors: [RetrieveError]?

    enum CodingKeys: String, CodingKey {
        case success
        case format
        case invoice
        case sourceXml = "source_xml"
        case errors
    }
}

/// Invoice data returned from the retrieve endpoint
public struct RetrievedInvoiceData: Codable, Sendable {
    public var number: String?
    public var date: String?
    public var dueDate: String?
    public var seller: Party?
    public var buyer: Party?
    public var items: [LineItem]?
    public var currency: String?
    public var notes: String?
    public var leitwegId: String?
    public var buyerReference: String?
    public var tipoDocumento: String?
}

// MARK: - Dry-Run Validation

/// Result of a pre-validation (dry-run) request
public struct DryRunResult: Codable, Sendable {
    public var valid: Bool
    public var format: FormatInfo?
    public var errors: [ValidationError]?

    /// Whether validation passed
    public var isValid: Bool { valid }
}

// MARK: - Internal Response Types

/// Generate response from the API
struct GenerateResponse: Codable {
    var pdfBase64: String
    var filename: String
    var format: FormatInfo
    var account: AccountInfo?

    enum CodingKeys: String, CodingKey {
        case pdfBase64 = "pdf_base64"
        case filename
        case format
        case account
    }
}

/// Error response from the API
struct ErrorResponse: Codable {
    var error: String
    var message: String?
    var details: [ValidationError]?
}
