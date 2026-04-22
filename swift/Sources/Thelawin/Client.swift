import Foundation

/// Main client for interacting with the thelawin.dev API
public final class ThelawinClient: Sendable {
    private let apiKey: String
    private let apiUrl: String
    private let timeout: TimeInterval
    private let session: URLSession

    /// Create a new ThelawinClient
    /// - Parameters:
    ///   - apiKey: Your API key (env_sandbox_* or env_live_*)
    ///   - apiUrl: Custom API base URL (default: https://api.thelawin.dev)
    ///   - timeout: Request timeout in seconds (default: 30)
    public init(
        apiKey: String,
        apiUrl: String = "https://api.thelawin.dev",
        timeout: TimeInterval = 30
    ) throws {
        guard !apiKey.isEmpty else {
            throw ThelawinError.invalidApiKey
        }
        self.apiKey = apiKey
        self.apiUrl = apiUrl.hasSuffix("/") ? String(apiUrl.dropLast()) : apiUrl
        self.timeout = timeout

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = timeout
        self.session = URLSession(configuration: config)
    }

    /// Create a new invoice builder with fluent API
    /// - Returns: An InvoiceBuilder configured with this client
    public func invoice() -> InvoiceBuilder {
        InvoiceBuilder(client: self)
    }

    /// Generate an invoice directly from a GenerateRequest
    /// - Parameter request: The fully configured generate request
    /// - Returns: An InvoiceResult (success or failure with validation errors)
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
            throw ThelawinError.networkError("Invalid response")
        }

        let decoder = JSONDecoder()

        switch httpResponse.statusCode {
        case 200:
            let generateResponse = try decoder.decode(GenerateResponse.self, from: data)
            return .success(InvoiceSuccess(
                pdfBase64: generateResponse.pdfBase64,
                filename: generateResponse.filename,
                format: generateResponse.format,
                account: generateResponse.account
            ))

        case 402:
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            throw ThelawinError.quotaExceeded(errorResponse.message ?? "Quota exceeded")

        case 422:
            let errorResponse = try decoder.decode(ErrorResponse.self, from: data)
            if let details = errorResponse.details {
                return .failure(details)
            }
            throw ThelawinError.apiError(
                statusCode: 422,
                message: errorResponse.message ?? errorResponse.error,
                code: errorResponse.error
            )

        default:
            let errorResponse = try? decoder.decode(ErrorResponse.self, from: data)
            throw ThelawinError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }
    }

    /// Pre-validate invoice data without generating PDF (dry-run)
    /// - Parameter request: The fully configured generate request
    /// - Returns: A DryRunResult with validation info
    public func validate(_ request: GenerateRequest) async throws -> DryRunResult {
        let body = try JSONEncoder().encode(request)

        var urlRequest = URLRequest(url: URL(string: "\(apiUrl)/v1/validate")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThelawinError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 || httpResponse.statusCode == 422 else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ThelawinError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }

        return try JSONDecoder().decode(DryRunResult.self, from: data)
    }

    /// Extract invoice data from a PDF or XML document
    /// - Parameters:
    ///   - dataBase64: Base64-encoded PDF or XML content
    ///   - contentType: MIME type hint (e.g., "application/pdf", "application/xml")
    ///   - includeSourceXml: Whether to include the raw source XML in the response
    /// - Returns: A RetrieveResponse with extracted invoice data
    public func retrieve(
        dataBase64: String,
        contentType: String? = nil,
        includeSourceXml: Bool = false
    ) async throws -> RetrieveResponse {
        let requestBody = RetrieveRequest(
            dataBase64: dataBase64,
            contentType: contentType,
            includeSourceXml: includeSourceXml ? true : nil
        )
        let body = try JSONEncoder().encode(requestBody)

        var urlRequest = URLRequest(url: URL(string: "\(apiUrl)/v1/retrieve")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThelawinError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ThelawinError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }

        return try JSONDecoder().decode(RetrieveResponse.self, from: data)
    }

    /// Get account information (quota, plan, etc.)
    /// - Returns: AccountInfo with remaining credits and plan details
    public func getAccount() async throws -> AccountInfo {
        var request = URLRequest(url: URL(string: "\(apiUrl)/v1/account")!)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ThelawinError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ThelawinError.apiError(
                statusCode: httpResponse.statusCode,
                message: errorResponse?.message ?? "HTTP \(httpResponse.statusCode)",
                code: errorResponse?.error
            )
        }

        return try JSONDecoder().decode(AccountInfo.self, from: data)
    }
}
