import Foundation

/// Main client for interacting with the envoice.dev API
public final class EnvoiceClient: Sendable {
    private let apiKey: String
    private let apiUrl: String
    private let timeout: TimeInterval
    private let session: URLSession

    /// Create a new EnvoiceClient
    public init(
        apiKey: String,
        apiUrl: String = "https://api.envoice.dev",
        timeout: TimeInterval = 30
    ) throws {
        guard !apiKey.isEmpty else {
            throw EnvoiceError.invalidApiKey
        }
        self.apiKey = apiKey
        self.apiUrl = apiUrl.hasSuffix("/") ? String(apiUrl.dropLast()) : apiUrl
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: config)
    }

    /// Create a new invoice builder
    public func invoice() -> InvoiceBuilder {
        InvoiceBuilder(client: self)
    }

    /// Generate an invoice directly
    public func generateInvoice(_ request: GenerateRequest) async throws -> InvoiceResult {
        let encoder = JSONEncoder()
        let body = try encoder.encode(request)

        var urlRequest = URLRequest(url: URL(string: "\(apiUrl)/v1/generate")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnvoiceError.networkError("Invalid response")
        }

        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let generateResponse = try decoder.decode(GenerateResponse.self, from: data)
            return .success(InvoiceSuccess(
                pdfBase64: generateResponse.pdfBase64,
                filename: generateResponse.filename,
                validation: generateResponse.validation,
                account: generateResponse.account
            ))

        case 402:
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw EnvoiceError.quotaExceeded(errorResponse.message ?? "Quota exceeded")

        case 422:
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            if let details = errorResponse.details {
                return .failure(details)
            }
            throw EnvoiceError.apiError(
                statusCode: 422,
                message: errorResponse.message ?? errorResponse.error,
                code: errorResponse.error
            )

        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw EnvoiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }
    }

    /// Validate an existing PDF
    public func validate(pdfBase64: String) async throws -> [String: Any] {
        let body = try JSONEncoder().encode(["pdf_base64": pdfBase64])

        var request = URLRequest(url: URL(string: "\(apiUrl)/v1/validate")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnvoiceError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw EnvoiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }

        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    /// Get account information
    public func getAccount() async throws -> AccountInfo {
        var request = URLRequest(url: URL(string: "\(apiUrl)/v1/account")!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw EnvoiceError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw EnvoiceError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }

        return try JSONDecoder().decode(AccountInfo.self, from: data)
    }
}
