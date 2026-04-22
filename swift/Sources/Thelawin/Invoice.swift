import Foundation

/// Result of an invoice generation
public enum InvoiceResult: Sendable {
    case success(InvoiceSuccess)
    case failure([ValidationError])

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var isFailure: Bool {
        !isSuccess
    }
}

/// Successful invoice generation result
public struct InvoiceSuccess: Sendable {
    public let pdfBase64: String
    public let filename: String
    public let format: FormatInfo
    public let account: AccountInfo?

    /// Save the output to a file (PDF or XML depending on format)
    /// - Parameter url: File URL to save to
    public func save(to url: URL) throws {
        let data = try toData()
        try data.write(to: url)
    }

    /// Get the output as raw bytes
    /// - Returns: Decoded binary data
    public func toData() throws -> Data {
        guard let data = Data(base64Encoded: pdfBase64) else {
            throw ThelawinError.networkError("Failed to decode output data")
        }
        return data
    }

    /// Get the output as a data URL
    /// - Returns: Data URL string with appropriate MIME type
    public func toDataUrl() -> String {
        let mimeType = format.isXmlOnly ? "application/xml" : "application/pdf"
        return "data:\(mimeType);base64,\(pdfBase64)"
    }

    /// Whether the output is XML-only (no visual PDF)
    public var isXmlOnly: Bool {
        format.isXmlOnly
    }

    /// Get legal warnings from format detection
    public var warnings: [LegalWarning] {
        format.warnings ?? []
    }
}

/// Fluent builder for creating invoices (matches the Ruby SDK pattern)
public final class InvoiceBuilder: @unchecked Sendable {
    private let client: ThelawinClient
    private var _format: String = "auto"
    private var _profile: String = "en16931"
    private var _number: String?
    private var _date: String?
    private var _dueDate: String?
    private var _seller: Party?
    private var _buyer: Party?
    private var _items: [LineItem] = []
    private var _payment: PaymentInfo?
    private var _currency = "EUR"
    private var _notes: String?
    private var _leitwegId: String?
    private var _buyerReference: String?
    private var _tipoDocumento: String?
    private var _template = "minimal"
    private var _locale = "en"
    private var _customization = Customization()

    init(client: ThelawinClient) {
        self.client = client
    }

    // MARK: - Format & Profile

    /// Set the output format
    /// - Parameter value: InvoiceFormat enum value
    /// - Returns: Self for chaining
    @discardableResult
    public func format(_ value: InvoiceFormat) -> Self {
        self._format = value.rawValue
        return self
    }

    /// Set the output format by string
    /// - Parameter value: "auto", "zugferd", "facturx", "xrechnung", "pdf", "ubl", "cii", "peppol", "fatturapa"
    /// - Returns: Self for chaining
    @discardableResult
    public func format(_ value: String) -> Self {
        self._format = value
        return self
    }

    /// Set the profile (for ZUGFeRD/Factur-X formats)
    /// - Parameter value: InvoiceProfile enum value
    /// - Returns: Self for chaining
    @discardableResult
    public func profile(_ value: InvoiceProfile) -> Self {
        self._profile = value.rawValue
        return self
    }

    /// Set the profile by string
    /// - Parameter value: "minimum", "basic_wl", "basic", "en16931", "extended"
    /// - Returns: Self for chaining
    @discardableResult
    public func profile(_ value: String) -> Self {
        self._profile = value
        return self
    }

    // MARK: - Core Fields

    /// Set the invoice number
    /// - Parameter value: Invoice number string
    /// - Returns: Self for chaining
    @discardableResult
    public func number(_ value: String) -> Self {
        self._number = value
        return self
    }

    /// Set the invoice date (YYYY-MM-DD)
    /// - Parameter value: Date string in ISO format
    /// - Returns: Self for chaining
    @discardableResult
    public func date(_ value: String) -> Self {
        self._date = value
        return self
    }

    /// Set the invoice date
    /// - Parameter value: Date object (formatted as YYYY-MM-DD)
    /// - Returns: Self for chaining
    @discardableResult
    public func date(_ value: Date) -> Self {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        self._date = formatter.string(from: value)
        return self
    }

    /// Set the due date
    /// - Parameter value: Due date string in ISO format
    /// - Returns: Self for chaining
    @discardableResult
    public func dueDate(_ value: String) -> Self {
        self._dueDate = value
        return self
    }

    // MARK: - Parties

    /// Set the seller
    /// - Parameter party: Party object
    /// - Returns: Self for chaining
    @discardableResult
    public func seller(_ party: Party) -> Self {
        self._seller = party
        return self
    }

    /// Set the seller using closure
    /// - Parameter configure: Closure that configures the Party
    /// - Returns: Self for chaining
    @discardableResult
    public func seller(_ configure: (inout Party) -> Void) -> Self {
        var party = Party(name: "")
        configure(&party)
        self._seller = party
        return self
    }

    /// Set the buyer
    /// - Parameter party: Party object
    /// - Returns: Self for chaining
    @discardableResult
    public func buyer(_ party: Party) -> Self {
        self._buyer = party
        return self
    }

    /// Set the buyer using closure
    /// - Parameter configure: Closure that configures the Party
    /// - Returns: Self for chaining
    @discardableResult
    public func buyer(_ configure: (inout Party) -> Void) -> Self {
        var party = Party(name: "")
        configure(&party)
        self._buyer = party
        return self
    }

    // MARK: - Line Items

    /// Add a line item
    /// - Parameter item: LineItem object
    /// - Returns: Self for chaining
    @discardableResult
    public func addItem(_ item: LineItem) -> Self {
        self._items.append(item)
        return self
    }

    /// Add a line item using closure
    /// - Parameter configure: Closure that configures the LineItem
    /// - Returns: Self for chaining
    @discardableResult
    public func addItem(_ configure: (inout LineItem) -> Void) -> Self {
        var item = LineItem(description: "", quantity: 1, unitPrice: 0)
        configure(&item)
        self._items.append(item)
        return self
    }

    // MARK: - Payment & Currency

    /// Set payment info
    /// - Parameter info: PaymentInfo object
    /// - Returns: Self for chaining
    @discardableResult
    public func payment(_ info: PaymentInfo) -> Self {
        self._payment = info
        return self
    }

    /// Set the currency
    /// - Parameter value: ISO 4217 currency code (default: EUR)
    /// - Returns: Self for chaining
    @discardableResult
    public func currency(_ value: String) -> Self {
        self._currency = value
        return self
    }

    // MARK: - Format-Specific Fields

    /// Set invoice notes/comments
    /// - Parameter value: Notes text
    /// - Returns: Self for chaining
    @discardableResult
    public func notes(_ value: String) -> Self {
        self._notes = value
        return self
    }

    /// Set Leitweg-ID for XRechnung (German B2G)
    /// - Parameter value: e.g., "04011000-12345-67"
    /// - Returns: Self for chaining
    @discardableResult
    public func leitwegId(_ value: String) -> Self {
        self._leitwegId = value
        return self
    }

    /// Set buyer reference for Peppol
    /// - Parameter value: Purchase order reference
    /// - Returns: Self for chaining
    @discardableResult
    public func buyerReference(_ value: String) -> Self {
        self._buyerReference = value
        return self
    }

    /// Set document type for FatturaPA
    /// - Parameter value: "TD01" (invoice), "TD04" (credit note), etc.
    /// - Returns: Self for chaining
    @discardableResult
    public func tipoDocumento(_ value: String) -> Self {
        self._tipoDocumento = value
        return self
    }

    // MARK: - Template & Locale

    /// Set the template style
    /// - Parameter value: "minimal", "classic", or "compact"
    /// - Returns: Self for chaining
    @discardableResult
    public func template(_ value: String) -> Self {
        self._template = value
        return self
    }

    /// Set the locale
    /// - Parameter value: "de", "en", "fr", "es", "it"
    /// - Returns: Self for chaining
    @discardableResult
    public func locale(_ value: String) -> Self {
        self._locale = value
        return self
    }

    // MARK: - Customization

    /// Set logo from file URL
    /// - Parameters:
    ///   - url: File URL of the logo image
    ///   - widthMm: Optional logo width in mm
    /// - Returns: Self for chaining
    @discardableResult
    public func logoFile(_ url: URL, widthMm: Int? = nil) throws -> Self {
        let data = try Data(contentsOf: url)
        _customization.logoBase64 = data.base64EncodedString()
        _customization.logoWidthMm = widthMm
        return self
    }

    /// Set logo from Base64 string
    /// - Parameters:
    ///   - base64: Base64-encoded logo image
    ///   - widthMm: Optional logo width in mm
    /// - Returns: Self for chaining
    @discardableResult
    public func logoBase64(_ base64: String, widthMm: Int? = nil) -> Self {
        _customization.logoBase64 = base64
        _customization.logoWidthMm = widthMm
        return self
    }

    /// Set footer text
    /// - Parameter text: Footer text string
    /// - Returns: Self for chaining
    @discardableResult
    public func footerText(_ text: String) -> Self {
        _customization.footerText = text
        return self
    }

    /// Set accent color
    /// - Parameter color: Hex color code (e.g., "#8b5cf6")
    /// - Returns: Self for chaining
    @discardableResult
    public func accentColor(_ color: String) -> Self {
        _customization.accentColor = color
        return self
    }

    // MARK: - Actions

    /// Generate the invoice
    /// - Returns: InvoiceResult (success with PDF/XML data, or failure with validation errors)
    public func generate() async throws -> InvoiceResult {
        var errors: [ValidationError] = []

        if _number == nil {
            errors.append(ValidationError(path: "$.invoice.number", code: "REQUIRED", message: "Invoice number is required"))
        }
        if _date == nil {
            errors.append(ValidationError(path: "$.invoice.date", code: "REQUIRED", message: "Invoice date is required"))
        }
        if _seller == nil {
            errors.append(ValidationError(path: "$.invoice.seller", code: "REQUIRED", message: "Seller information is required"))
        }
        if _buyer == nil {
            errors.append(ValidationError(path: "$.invoice.buyer", code: "REQUIRED", message: "Buyer information is required"))
        }
        if _items.isEmpty {
            errors.append(ValidationError(path: "$.invoice.items", code: "REQUIRED", message: "At least one line item is required"))
        }

        if !errors.isEmpty {
            return .failure(errors)
        }

        let request = buildRequest()
        return try await client.generateInvoice(request)
    }

    /// Pre-validate the invoice without generating (dry-run)
    /// - Returns: DryRunResult with validation info
    public func validate() async throws -> DryRunResult {
        var errors: [ValidationError] = []

        if _number == nil {
            errors.append(ValidationError(path: "$.invoice.number", code: "REQUIRED", message: "Invoice number is required"))
        }
        if _date == nil {
            errors.append(ValidationError(path: "$.invoice.date", code: "REQUIRED", message: "Invoice date is required"))
        }
        if _seller == nil {
            errors.append(ValidationError(path: "$.invoice.seller", code: "REQUIRED", message: "Seller information is required"))
        }
        if _buyer == nil {
            errors.append(ValidationError(path: "$.invoice.buyer", code: "REQUIRED", message: "Buyer information is required"))
        }
        if _items.isEmpty {
            errors.append(ValidationError(path: "$.invoice.items", code: "REQUIRED", message: "At least one line item is required"))
        }

        if !errors.isEmpty {
            return DryRunResult(valid: false, format: nil, errors: errors)
        }

        let request = buildRequest()
        return try await client.validate(request)
    }

    // MARK: - Private

    private func buildRequest() -> GenerateRequest {
        GenerateRequest(
            format: _format,
            profile: _profile,
            template: _template,
            locale: _locale,
            invoice: InvoiceData(
                number: _number!,
                date: _date!,
                dueDate: _dueDate,
                seller: _seller!,
                buyer: _buyer!,
                items: _items,
                payment: _payment,
                currency: _currency,
                notes: _notes,
                leitwegId: _leitwegId,
                buyerReference: _buyerReference,
                tipoDocumento: _tipoDocumento
            ),
            customization: _customization.isEmpty ? nil : _customization
        )
    }
}
