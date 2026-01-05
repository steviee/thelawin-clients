import XCTest
@testable import Envoice

final class EnvoiceTests: XCTestCase {

    func testClientRequiresApiKey() {
        XCTAssertThrowsError(try EnvoiceClient(apiKey: "")) { error in
            XCTAssertEqual(error as? EnvoiceError, EnvoiceError.invalidApiKey)
        }
    }

    func testClientCreatesWithValidApiKey() throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")
        XCTAssertNotNil(client)
    }

    func testInvoiceReturnsBuilder() throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")
        let builder = client.invoice()
        XCTAssertNotNil(builder)
    }

    func testBuilderFluentInterface() throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")
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

    func testBuilderValidatesRequiredFields() async throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")
        let result = try await client.invoice().generate()

        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let errors):
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.number" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.date" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.seller" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.buyer" })
            XCTAssertTrue(errors.contains { $0.path == "$.invoice.items" })
        }
    }

    func testBuilderAcceptsPartyObjects() throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")

        let seller = Party(
            name: "Acme GmbH",
            city: "Berlin",
            country: "DE",
            vatId: "DE123456789"
        )

        let builder = client.invoice().seller(seller)
        XCTAssertNotNil(builder)
    }

    func testBuilderAcceptsPartyClosure() throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")

        let builder = client.invoice()
            .seller { party in
                party.name = "Acme GmbH"
                party.vatId = "DE123456789"
                party.city = "Berlin"
            }

        XCTAssertNotNil(builder)
    }

    func testBuilderAcceptsLineItems() throws {
        let client = try EnvoiceClient(apiKey: "env_sandbox_test")

        let item = LineItem(
            description: "Consulting",
            quantity: 8,
            unit: "HUR",
            unitPrice: 150.0,
            vatRate: 19.0
        )

        let builder = client.invoice().addItem(item)
        XCTAssertNotNil(builder)
    }

    func testSuccessResultMethods() throws {
        let success = InvoiceSuccess(
            pdfBase64: "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
            filename: "invoice-2026-001.pdf",
            validation: ValidationResult(status: "valid", profile: "EN16931", version: "2.3.2", warnings: nil),
            account: AccountInfo(remaining: 499, plan: "starter", overageCount: nil, overageAllowed: nil, warning: nil)
        )

        let data = try success.toData()
        XCTAssertTrue(data.count > 0)

        let str = String(data: data, encoding: .utf8)!
        XCTAssertTrue(str.hasPrefix("%PDF"))

        let dataUrl = success.toDataUrl()
        XCTAssertTrue(dataUrl.hasPrefix("data:application/pdf;base64,"))
    }
}
