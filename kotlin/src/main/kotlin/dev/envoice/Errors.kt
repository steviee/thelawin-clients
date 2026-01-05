package dev.envoice

/**
 * Base exception class for all envoice SDK errors
 */
open class EnvoiceException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Exception thrown when the API returns validation errors
 */
class EnvoiceValidationException(
    val errors: List<ValidationError>,
    val statusCode: Int = 422
) : EnvoiceException(
    "Validation failed: ${errors.joinToString("; ") { "${it.path}: ${it.message}" }}"
) {
    /**
     * Get a user-friendly error message
     */
    fun toUserMessage(): String = errors.joinToString("\n") { "- ${it.path}: ${it.message}" }
}

/**
 * Exception thrown when the API returns an HTTP error
 */
open class EnvoiceApiException(
    message: String,
    val statusCode: Int,
    val code: String? = null
) : EnvoiceException(message)

/**
 * Exception thrown when a network request fails
 */
class EnvoiceNetworkException(
    message: String,
    cause: Throwable? = null
) : EnvoiceException(message, cause)

/**
 * Exception thrown when quota is exceeded
 */
class EnvoiceQuotaExceededException(message: String) : EnvoiceApiException(message, 402, "quota_exceeded")
