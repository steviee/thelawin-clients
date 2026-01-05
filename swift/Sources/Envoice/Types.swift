import Foundation

/// Party (seller or buyer) information
public struct Party: Codable, Sendable {
    public var name: String
    public var street: String?
    public var city: String?
    public var postalCode: String?
    public var country: String?
    public var vatId: String?
    public var email: String?
    public var phone: String?

    public init(
        name: String,
        street: String? = nil,
        city: String? = nil,
        postalCode: String? = nil,
        country: String? = nil,
        vatId: String? = nil,
        email: String? = nil,
        phone: String? = nil
    ) {
        self.name = name
        self.street = street
        self.city = city
        self.postalCode = postalCode
        self.country = country
        self.vatId = vatId
        self.email = email
        self.phone = phone
    }
}

/// Line item in an invoice
public struct LineItem: Codable, Sendable {
    public var description: String
    public var quantity: Double
    public var unit: String
    public var unitPrice: Double
    public var vatRate: Double

    public init(
        description: String,
        quantity: Double,
        unit: String = "C62",
        unitPrice: Double,
        vatRate: Double = 19.0
    ) {
        self.description = description
        self.quantity = quantity
        self.unit = unit
        self.unitPrice = unitPrice
        self.vatRate = vatRate
    }
}

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

/// Customization options
public struct Customization: Codable, Sendable {
    public var logoBase64: String?
    public var logoWidthMm: Int?
    public var footerText: String?
    public var accentColor: String?
}

/// Invoice data
public struct InvoiceData: Codable, Sendable {
    public var number: String
    public var date: String
    public var dueDate: String?
    public var seller: Party
    public var buyer: Party
    public var items: [LineItem]
    public var payment: PaymentInfo?
    public var currency: String
}

/// Generate request
public struct GenerateRequest: Codable, Sendable {
    public var template: String
    public var locale: String
    public var invoice: InvoiceData
    public var customization: Customization?
}

/// Validation result
public struct ValidationResult: Codable, Sendable {
    public var status: String
    public var profile: String
    public var version: String
    public var warnings: [String]?
}

/// Account info
public struct AccountInfo: Codable, Sendable {
    public var remaining: Int
    public var plan: String
    public var overageCount: Int?
    public var overageAllowed: Int?
    public var warning: String?
}

/// Generate response
struct GenerateResponse: Codable {
    var pdfBase64: String
    var filename: String
    var validation: ValidationResult
    var account: AccountInfo?

    enum CodingKeys: String, CodingKey {
        case pdfBase64 = "pdf_base64"
        case filename
        case validation
        case account
    }
}

/// Validation error
public struct ValidationError: Codable, Sendable {
    public var path: String
    public var code: String
    public var message: String
    public var severity: String?
}

/// Error response
struct ErrorResponse: Codable {
    var error: String
    var message: String?
    var details: [ValidationError]?
}
