import Foundation

/// Base error for all envoice SDK errors
public enum EnvoiceError: Error, Sendable {
    case invalidApiKey
    case validationFailed([ValidationError])
    case quotaExceeded(String)
    case apiError(statusCode: Int, message: String, code: String?)
    case networkError(String)
}

extension EnvoiceError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidApiKey:
            return "API key is required"
        case .validationFailed(let errors):
            return "Validation failed: " + errors.map { "\($0.path): \($0.message)" }.joined(separator: "; ")
        case .quotaExceeded(let message):
            return message
        case .apiError(_, let message, _):
            return message
        case .networkError(let message):
            return message
        }
    }
}
