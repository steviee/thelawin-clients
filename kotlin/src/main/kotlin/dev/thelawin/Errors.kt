package dev.thelawin

/**
 * Basis-Exception fuer alle thelawin SDK Fehler
 */
open class ThelawinException(message: String, cause: Throwable? = null) : Exception(message, cause)

/**
 * Exception bei Validierungsfehlern (422)
 */
class ThelawinValidationException(
    val errors: List<ValidationError>,
    val statusCode: Int = 422
) : ThelawinException(
    "Validation failed: ${errors.joinToString("; ") { "${it.path}: ${it.message}" }}"
) {
    /**
     * Benutzerfreundliche Fehlermeldung
     */
    fun toUserMessage(): String = errors.joinToString("\n") { "- ${it.path}: ${it.message}" }
}

/**
 * Exception bei HTTP-Fehlern der API
 */
open class ThelawinApiException(
    message: String,
    val statusCode: Int,
    val code: String? = null
) : ThelawinException(message)

/**
 * Exception bei Netzwerkfehlern
 */
class ThelawinNetworkException(
    message: String,
    cause: Throwable? = null
) : ThelawinException(message, cause)

/**
 * Exception bei ueberschrittenem Quota (402)
 */
class ThelawinQuotaExceededException(message: String) : ThelawinApiException(message, 402, "quota_exceeded")

/**
 * Exception bei fehlender/ungueltiger Authentifizierung (401)
 */
class ThelawinAuthException(message: String) : ThelawinApiException(message, 401, "unauthorized")
