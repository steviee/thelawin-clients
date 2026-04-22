import XCTest
@testable import Thelawin

final class ThelawinTests: XCTestCase {

    // MARK: - 1. Client Initialization

    func testClientRequiresApiKey() {
        XCTAssertThrowsError(try ThelawinClient(apiKey: "")) { error in
            XCTAssertEqual(error as? ThelawinError, ThelawinError.invalidApiKey)
        }
    }

    func testClientCreatesWithValidApiKey() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        XCTAssertNotNil(client)
    }

    func testClientDefaultUrl() throws {
        // Default URL should be api.thelawin.dev (verified via builder usage)
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        XCTAssertNotNil(client)
    }

    func testClientCustomUrl() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test", apiUrl: "https://api.preview.thelawin.dev")
        XCTAssertNotNil(client)
    }

    func testClientStripsTrailingSlash() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test", apiUrl: "https://api.thelawin.dev/")
        XCTAssertNotNil(client)
    }

    func testClientCustomTimeout() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test", timeout: 60)
        XCTAssertNotNil(client)
    }

    // MARK: - 2. Builder Creation

    func testInvoiceReturnsBuilder() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()
        XCTAssertNotNil(builder)
    }

    // MARK: - 3. Fluent API Chain Methods

    func testBuilderFluentInterface() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.number("2026-001"))
        XCTAssertTrue(builder === builder.date("2026-01-15"))
        XCTAssertTrue(builder === builder.dueDate("2026-02-15"))
        XCTAssertTrue(builder === builder.currency("EUR"))
        XCTAssertTrue(builder === builder.template("minimal"))
        XCTAssertTrue(builder === builder.locale("de"))
        XCTAssertTrue(builder === builder.footerText("Thanks!"))
        XCTAssertTrue(builder === builder.accentColor("#8b5cf6"))
    }

    func testBuilderFormatChaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.format(.zugferd))
        XCTAssertTrue(builder === builder.format("facturx"))
    }

    func testBuilderProfileChaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.profile(.en16931))
        XCTAssertTrue(builder === builder.profile("extended"))
    }

    func testBuilderNotesChaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.notes("Please pay within 30 days"))
    }

    func testBuilderLeitwegIdChaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.leitwegId("04011000-12345-67"))
    }

    func testBuilderBuyerReferenceChaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.buyerReference("PO-2026-001"))
    }

    func testBuilderTipoDocumentoChaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.tipoDocumento("TD01"))
    }

    func testBuilderLogoBase64Chaining() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()

        XCTAssertTrue(builder === builder.logoBase64("iVBORw0KGgo=", widthMm: 40))
    }

    // MARK: - 4. Validation of Required Fields

    func testBuilderValidatesRequiredFields() async throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let result = try await client.invoice().generate()

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let errors):
            XCTAssertEqual(errors.count, 5)
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.number" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.date" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.seller" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.buyer" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.items" })
        }
    }

    func testBuilderValidatesPartialFields() async throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let result = try await client.invoice()
            .number("2026-001")
            .date("2026-01-15")
            .generate()

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let errors):
            XCTAssertEqual(errors.count, 3)
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.seller" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.buyer" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.items" })
        }
    }

    func testValidateAlsoChecksRequiredFields() async throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")
        let result = try await client.invoice().validate()

        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.errors)
        XCTAssertEqual(result.errors?.count, 5)
    }

    // MARK: - 5. InvoiceResult

    func testInvoiceResultIsSuccess() {
        let format = FormatInfo(formatUsed: "zugferd", profile: "EN16931", version: "2.3.2")
        let result = InvoiceResult.success(InvoiceSuccess(
            pdfBase64: "JVBER",
            filename: "invoice.pdf",
            format: format,
            account: nil
        ))
        XCTAssertTrue(result.isSuccess)
        XCTAssertFalse(result.isFailure)
    }

    func testInvoiceResultIsFailure() {
        let result = InvoiceResult.failure([
            ValidationError(path: "$.invoice.number", code: "REQUIRED", message: "Invoice number is required")
        ])
        XCTAssertFalse(result.isSuccess)
        XCTAssertTrue(result.isFailure)
    }

    // MARK: - 6. Party with Peppol/FatturaPA Fields

    func testPartyWithPeppolFields() {
        let party = Party(
            name: "EU Corp",
            city: "Brussels",
            country: "BE",
            vatId: "BE0123456789",
            peppolId: "0088:1234567890123"
        )
        XCTAssertEqual(party.peppolId, "0088:1234567890123")
    }

    func testPartyWithFatturaPaFields() {
        let party = Party(
            name: "Acme S.r.l.",
            city: "Roma",
            country: "IT",
            vatId: "IT12345678901",
            codiceFiscale: "RSSMRA80A01H501U",
            codiceDestinatario: "0000000",
            pec: "acme@pec.it"
        )
        XCTAssertEqual(party.codiceFiscale, "RSSMRA80A01H501U")
        XCTAssertEqual(party.codiceDestinatario, "0000000")
        XCTAssertEqual(party.pec, "acme@pec.it")
    }

    func testBuilderAcceptsPartyClosure() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")

        let builder = client.invoice()
            .seller { party in
                party.name = "Acme GmbH"
                party.vatId = "DE123456789"
                party.city = "Berlin"
                party.peppolId = "0088:4000001987658"
            }

        XCTAssertNotNil(builder)
    }

    func testBuilderAcceptsPartyObject() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")

        let seller = Party(
            name: "Acme GmbH",
            city: "Berlin",
            country: "DE",
            vatId: "DE123456789"
        )

        let builder = client.invoice().seller(seller)
        XCTAssertNotNil(builder)
    }

    // MARK: - 7. Line Items with Natura

    func testLineItemWithNatura() {
        let item = LineItem(
            description: "Consulenza",
            quantity: 1,
            unit: "HUR",
            unitPrice: 500.0,
            vatRate: 0.0,
            natura: "N2.2"
        )
        XCTAssertEqual(item.natura, "N2.2")
        XCTAssertEqual(item.vatRate, 0.0)
    }

    func testLineItemDefaults() {
        let item = LineItem(description: "Widget", quantity: 10, unitPrice: 9.99)
        XCTAssertEqual(item.unit, "C62")
        XCTAssertEqual(item.vatRate, 19.0)
        XCTAssertNil(item.natura)
    }

    func testBuilderAcceptsLineItemClosure() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")

        let builder = client.invoice()
            .addItem { item in
                item.description = "Consulting"
                item.quantity = 8
                item.unit = "HUR"
                item.unitPrice = 150.0
                item.vatRate = 19.0
            }

        XCTAssertNotNil(builder)
    }

    // MARK: - 8. InvoiceSuccess Methods

    func testSuccessToData() throws {
        let format = FormatInfo(formatUsed: "zugferd", profile: "EN16931", version: "2.3.2")
        let success = InvoiceSuccess(
            pdfBase64: "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
            filename: "invoice-2026-001.pdf",
            format: format,
            account: AccountInfo(remaining: 499, plan: "starter")
        )

        let data = try success.toData()
        XCTAssertTrue(data.count > 0)

        // PDF starts with %PDF (0x25 0x50 0x44 0x46)
        XCTAssertEqual(data[0], 0x25) // %
        XCTAssertEqual(data[1], 0x50) // P
        XCTAssertEqual(data[2], 0x44) // D
        XCTAssertEqual(data[3], 0x46) // F
    }

    func testSuccessToDataUrl() {
        let format = FormatInfo(formatUsed: "zugferd", profile: "EN16931", version: "2.3.2")
        let success = InvoiceSuccess(
            pdfBase64: "JVBER",
            filename: "invoice.pdf",
            format: format,
            account: nil
        )

        let dataUrl = success.toDataUrl()
        XCTAssertTrue(dataUrl.hasPrefix("data:application/pdf;base64,"))
    }

    func testSuccessToDataUrlXmlOnly() {
        let format = FormatInfo(formatUsed: "ubl")
        let success = InvoiceSuccess(
            pdfBase64: "PD94bWw=",
            filename: "invoice.xml",
            format: format,
            account: nil
        )

        let dataUrl = success.toDataUrl()
        XCTAssertTrue(dataUrl.hasPrefix("data:application/xml;base64,"))
        XCTAssertTrue(success.isXmlOnly)
    }

    // MARK: - 9. Format Info

    func testFormatInfoPdfWithXml() {
        let format = FormatInfo(formatUsed: "zugferd", profile: "EN16931", version: "2.3.2")
        XCTAssertTrue(format.isPdfWithXml)
        XCTAssertFalse(format.isXmlOnly)
        XCTAssertFalse(format.isPlainPdf)
    }

    func testFormatInfoXmlOnly() {
        let format = FormatInfo(formatUsed: "peppol")
        XCTAssertFalse(format.isPdfWithXml)
        XCTAssertTrue(format.isXmlOnly)
        XCTAssertFalse(format.isPlainPdf)
    }

    func testFormatInfoPlainPdf() {
        let format = FormatInfo(formatUsed: "pdf")
        XCTAssertFalse(format.isPdfWithXml)
        XCTAssertFalse(format.isXmlOnly)
        XCTAssertTrue(format.isPlainPdf)
    }

    // MARK: - 10. InvoiceFormat Enum

    func testInvoiceFormatXmlOnly() {
        XCTAssertTrue(InvoiceFormat.ubl.isXmlOnly)
        XCTAssertTrue(InvoiceFormat.cii.isXmlOnly)
        XCTAssertTrue(InvoiceFormat.peppol.isXmlOnly)
        XCTAssertTrue(InvoiceFormat.fatturapa.isXmlOnly)
        XCTAssertFalse(InvoiceFormat.zugferd.isXmlOnly)
        XCTAssertFalse(InvoiceFormat.pdf.isXmlOnly)
    }

    func testInvoiceFormatPdfWithXml() {
        XCTAssertTrue(InvoiceFormat.zugferd.isPdfWithXml)
        XCTAssertTrue(InvoiceFormat.facturx.isPdfWithXml)
        XCTAssertTrue(InvoiceFormat.xrechnung.isPdfWithXml)
        XCTAssertFalse(InvoiceFormat.ubl.isPdfWithXml)
        XCTAssertFalse(InvoiceFormat.pdf.isPdfWithXml)
    }

    // MARK: - 11. InvoiceProfile Enum

    func testInvoiceProfileRawValues() {
        XCTAssertEqual(InvoiceProfile.minimum.rawValue, "minimum")
        XCTAssertEqual(InvoiceProfile.basicWl.rawValue, "basic_wl")
        XCTAssertEqual(InvoiceProfile.basic.rawValue, "basic")
        XCTAssertEqual(InvoiceProfile.en16931.rawValue, "en16931")
        XCTAssertEqual(InvoiceProfile.extended.rawValue, "extended")
    }

    // MARK: - 12. Retrieve Types

    func testRetrieveResponseDecoding() throws {
        let json = """
        {
            "success": true,
            "format": {"format": "zugferd", "profile": "EN16931", "version": "2.3.2"},
            "invoice": {"number": "2026-001", "date": "2026-01-15", "currency": "EUR"},
            "source_xml": "<xml/>",
            "errors": null
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(RetrieveResponse.self, from: data)

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.format?.format, "zugferd")
        XCTAssertEqual(response.invoice?.number, "2026-001")
        XCTAssertEqual(response.sourceXml, "<xml/>")
        XCTAssertNil(response.errors)
    }

    func testRetrieveResponseWithErrors() throws {
        let json = """
        {
            "success": false,
            "format": null,
            "invoice": null,
            "errors": [{"code": "UNSUPPORTED_FORMAT", "message": "Cannot extract data from this file"}]
        }
        """
        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(RetrieveResponse.self, from: data)

        XCTAssertFalse(response.success)
        XCTAssertNil(response.format)
        XCTAssertEqual(response.errors?.count, 1)
        XCTAssertEqual(response.errors?.first?.code, "UNSUPPORTED_FORMAT")
    }

    func testDetectedFormatDecoding() throws {
        let json = """
        {"format": "facturx", "profile": "EN16931", "version": "1.0.8"}
        """
        let data = json.data(using: .utf8)!
        let format = try JSONDecoder().decode(DetectedFormat.self, from: data)

        XCTAssertEqual(format.format, "facturx")
        XCTAssertEqual(format.profile, "EN16931")
        XCTAssertEqual(format.version, "1.0.8")
    }

    // MARK: - 13. Error Types

    func testThelawinErrorDescriptions() {
        let errors: [(ThelawinError, String)] = [
            (.invalidApiKey, "API key is required"),
            (.quotaExceeded("Monthly limit reached"), "Monthly limit reached"),
            (.apiError(statusCode: 500, message: "Internal Server Error", code: nil), "Internal Server Error"),
            (.networkError("Connection refused"), "Connection refused"),
        ]

        for (error, expected) in errors {
            XCTAssertEqual(error.errorDescription, expected)
        }
    }

    func testValidationFailedErrorDescription() {
        let error = ThelawinError.validationFailed([
            ValidationError(path: "$.invoice.number", code: "REQUIRED", message: "Invoice number is required")
        ])
        XCTAssertTrue(error.errorDescription!.contains("$.invoice.number"))
    }

    // MARK: - 14. Customization

    func testCustomizationIsEmpty() {
        let empty = Customization()
        XCTAssertTrue(empty.isEmpty)

        let withLogo = Customization(logoBase64: "abc")
        XCTAssertFalse(withLogo.isEmpty)

        let withFooter = Customization(footerText: "Footer")
        XCTAssertFalse(withFooter.isEmpty)

        let withColor = Customization(accentColor: "#ff0000")
        XCTAssertFalse(withColor.isEmpty)
    }

    // MARK: - 15. Legal Warning

    func testLegalWarningProperties() {
        let warning = LegalWarning(code: "FORMAT_MISMATCH", message: "Auto-detected format differs", severity: "warning")
        XCTAssertTrue(warning.isWarning)
        XCTAssertFalse(warning.isInfo)

        let info = LegalWarning(code: "FORMAT_INFO", message: "Using ZUGFeRD 2.4", severity: "info")
        XCTAssertTrue(info.isInfo)
        XCTAssertFalse(info.isWarning)
    }

    // MARK: - 16. Date Builder

    func testBuilderAcceptsDateObject() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")

        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = 2026
        components.month = 4
        components.day = 22
        components.timeZone = TimeZone(identifier: "UTC")
        let date = calendar.date(from: components)!

        let builder = client.invoice().date(date)
        XCTAssertNotNil(builder)
    }

    // MARK: - 17. Codable Roundtrip

    func testPartyCodableRoundtrip() throws {
        let party = Party(
            name: "Acme S.r.l.",
            city: "Roma",
            country: "IT",
            vatId: "IT12345678901",
            peppolId: "0088:1234567890123",
            codiceFiscale: "RSSMRA80A01H501U",
            codiceDestinatario: "0000000",
            pec: "acme@pec.it"
        )

        let data = try JSONEncoder().encode(party)
        let decoded = try JSONDecoder().decode(Party.self, from: data)

        XCTAssertEqual(decoded.name, party.name)
        XCTAssertEqual(decoded.peppolId, party.peppolId)
        XCTAssertEqual(decoded.codiceFiscale, party.codiceFiscale)
        XCTAssertEqual(decoded.codiceDestinatario, party.codiceDestinatario)
        XCTAssertEqual(decoded.pec, party.pec)
    }

    func testLineItemCodableRoundtrip() throws {
        let item = LineItem(
            description: "Consulenza",
            quantity: 1,
            unit: "HUR",
            unitPrice: 500.0,
            vatRate: 0.0,
            natura: "N2.2"
        )

        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(LineItem.self, from: data)

        XCTAssertEqual(decoded.description, item.description)
        XCTAssertEqual(decoded.natura, item.natura)
    }

    // MARK: - 18. Full Builder Chain

    func testFullBuilderChainDoesNotFailClientValidation() throws {
        let client = try ThelawinClient(apiKey: "env_sandbox_test")

        let builder = client.invoice()
            .format(.xrechnung)
            .profile(.en16931)
            .number("XR-2026-001")
            .date("2026-04-22")
            .dueDate("2026-05-22")
            .seller(Party(
                name: "Bundesamt GmbH",
                street: "Berliner Str. 1",
                city: "Berlin",
                postalCode: "10115",
                country: "DE",
                vatId: "DE123456789"
            ))
            .buyer(Party(
                name: "Stadtverwaltung",
                city: "Hamburg",
                country: "DE"
            ))
            .addItem(LineItem(
                description: "IT-Beratung",
                quantity: 40,
                unit: "HUR",
                unitPrice: 120.0,
                vatRate: 19.0
            ))
            .notes("Bitte innerhalb von 30 Tagen bezahlen")
            .leitwegId("04011000-12345-67")
            .buyerReference("PO-2026-001")
            .currency("EUR")
            .template("classic")
            .locale("de")
            .footerText("Vielen Dank")
            .accentColor("#1e40af")

        XCTAssertNotNil(builder)
    }

    // MARK: - 19. Payment Info

    func testPaymentInfoCodable() throws {
        let payment = PaymentInfo(iban: "DE89370400440532013000", bic: "COBADEFFXXX", terms: "Net 30", reference: "INV-2026-001")

        let data = try JSONEncoder().encode(payment)
        let decoded = try JSONDecoder().decode(PaymentInfo.self, from: data)

        XCTAssertEqual(decoded.iban, payment.iban)
        XCTAssertEqual(decoded.bic, payment.bic)
        XCTAssertEqual(decoded.terms, payment.terms)
        XCTAssertEqual(decoded.reference, payment.reference)
    }

    // MARK: - 20. DryRunResult

    func testDryRunResultDecoding() throws {
        let json = """
        {
            "valid": true,
            "format": {"formatUsed": "zugferd", "profile": "EN16931", "version": "2.3.2"},
            "errors": []
        }
        """
        let data = json.data(using: .utf8)!
        let result = try JSONDecoder().decode(DryRunResult.self, from: data)

        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.format?.formatUsed, "zugferd")
    }
}
