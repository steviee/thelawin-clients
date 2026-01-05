import Foundation

/// Result of an invoice generation
public enum InvoiceResult: Sendable {
    case success(InvoiceSuccess)
    case failure([ValidationError])

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Successful invoice generation result
public struct InvoiceSuccess: Sendable {
    public let pdfBase64: String
    public let filename: String
    public let validation: ValidationResult
    public let account: AccountInfo?

    /// Save the PDF to a file
    public func savePdf(to url: URL) throws {
        let data = try toData()
        try data.write(to: url)
    }

    /// Get the PDF as Data
    public func toData() throws -> Data {
        guard let data = Data(base64Encoded: pdfBase64) else {
            throw EnvoiceError.networkError("Failed to decode PDF")
        }
        return data
    }

    /// Get the PDF as a data URL
    public func toDataUrl() -> String {
        "data:application/pdf;base64,\(pdfBase64)"
    }
}

/// Fluent builder for creating invoices
public final class InvoiceBuilder: @unchecked Sendable {
    private let client: EnvoiceClient
    private var number: String?
    private var date: String?
    private var dueDate: String?
    private var seller: Party?
    private var buyer: Party?
    private var items: [LineItem] = []
    private var payment: PaymentInfo?
    private var currency = "EUR"
    private var template = "minimal"
    private var locale = "en"
    private var customization = Customization()

    init(client: EnvoiceClient) {
        self.client = client
    }

    /// Set the invoice number
    @discardableResult
    public func number(_ value: String) -> Self {
        self.number = value
        return self
    }

    /// Set the invoice date (YYYY-MM-DD)
    @discardableResult
    public func date(_ value: String) -> Self {
        self.date = value
        return self
    }

    /// Set the invoice date
    @discardableResult
    public func date(_ value: Date) -> Self {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        self.date = formatter.string(from: value)
        return self
    }

    /// Set the due date
    @discardableResult
    public func dueDate(_ value: String) -> Self {
        self.dueDate = value
        return self
    }

    /// Set the seller
    @discardableResult
    public func seller(_ party: Party) -> Self {
        self.seller = party
        return self
    }

    /// Set the seller using closure
    @discardableResult
    public func seller(_ configure: (inout Party) -> Void) -> Self {
        var party = Party(name: "")
        configure(&party)
        self.seller = party
        return self
    }

    /// Set the buyer
    @discardableResult
    public func buyer(_ party: Party) -> Self {
        self.buyer = party
        return self
    }

    /// Set the buyer using closure
    @discardableResult
    public func buyer(_ configure: (inout Party) -> Void) -> Self {
        var party = Party(name: "")
        configure(&party)
        self.buyer = party
        return self
    }

    /// Add a line item
    @discardableResult
    public func addItem(_ item: LineItem) -> Self {
        self.items.append(item)
        return self
    }

    /// Add a line item using closure
    @discardableResult
    public func addItem(_ configure: (inout LineItem) -> Void) -> Self {
        var item = LineItem(description: "", quantity: 1, unitPrice: 0)
        configure(&item)
        self.items.append(item)
        return self
    }

    /// Set payment info
    @discardableResult
    public func payment(_ info: PaymentInfo) -> Self {
        self.payment = info
        return self
    }

    /// Set the currency
    @discardableResult
    public func currency(_ value: String) -> Self {
        self.currency = value
        return self
    }

    /// Set the template
    @discardableResult
    public func template(_ value: String) -> Self {
        self.template = value
        return self
    }

    /// Set the locale
    @discardableResult
    public func locale(_ value: String) -> Self {
        self.locale = value
        return self
    }

    /// Set logo from file URL
    @discardableResult
    public func logoFile(_ url: URL, widthMm: Int? = nil) throws -> Self {
        let data = try Data(contentsOf: url)
        customization.logoBase64 = data.base64EncodedString()
        customization.logoWidthMm = widthMm
        return self
    }

    /// Set logo from Base64
    @discardableResult
    public func logoBase64(_ base64: String, widthMm: Int? = nil) -> Self {
        customization.logoBase64 = base64
        customization.logoWidthMm = widthMm
        return self
    }

    /// Set footer text
    @discardableResult
    public func footerText(_ text: String) -> Self {
        customization.footerText = text
        return self
    }

    /// Set accent color
    @discardableResult
    public func accentColor(_ color: String) -> Self {
        customization.accentColor = color
        return self
    }

    /// Generate the invoice
    public func generate() async throws -> InvoiceResult {
        var errors: [ValidationError] = []

        if number == nil {
            errors.append(ValidationError(path: "$.invoice.number", code: "REQUIRED", message: "Invoice number is required"))
        }
        if date == nil {
            errors.append(ValidationError(path: "$.invoice.date", code: "REQUIRED", message: "Invoice date is required"))
        }
        if seller == nil {
            errors.append(ValidationError(path: "$.invoice.seller", code: "REQUIRED", message: "Seller information is required"))
        }
        if buyer == nil {
            errors.append(ValidationError(path: "$.invoice.buyer", code: "REQUIRED", message: "Buyer information is required"))
        }
        if items.isEmpty {
            errors.append(ValidationError(path: "$.invoice.items", code: "REQUIRED", message: "At least one line item is required"))
        }

        if !errors.isEmpty {
            return .failure(errors)
        }

        let hasCustomization = customization.logoBase64 != nil || customization.footerText != nil || customization.accentColor != nil

        let request = GenerateRequest(
            template: template,
            locale: locale,
            invoice: InvoiceData(
                number: number!,
                date: date!,
                dueDate: dueDate,
                seller: seller!,
                buyer: buyer!,
                items: items,
                payment: payment,
                currency: currency
            ),
            customization: hasCustomization ? customization : nil
        )

        return try await client.generateInvoice(request)
    }
}
