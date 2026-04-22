package dev.thelawin

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Unterstuetzte Rechnungsformate
 */
@Serializable
enum class InvoiceFormat {
    @SerialName("auto") AUTO,
    @SerialName("zugferd") ZUGFERD,
    @SerialName("facturx") FACTURX,
    @SerialName("xrechnung") XRECHNUNG,
    @SerialName("ubl") UBL,
    @SerialName("cii") CII,
    @SerialName("peppol") PEPPOL,
    @SerialName("fatturapa") FATTURAPA,
    @SerialName("pdf") PDF
}

/**
 * ZUGFeRD/Factur-X Profilstufen
 */
@Serializable
enum class InvoiceProfile {
    @SerialName("minimum") MINIMUM,
    @SerialName("basic_wl") BASIC_WL,
    @SerialName("basic") BASIC,
    @SerialName("en16931") EN16931,
    @SerialName("extended") EXTENDED
}

/**
 * Partei (Verkaeufer oder Kaeufer)
 */
@Serializable
data class Party(
    val name: String,
    val street: String? = null,
    val city: String? = null,
    @SerialName("postalCode") val postalCode: String? = null,
    val country: String? = null,
    @SerialName("vatId") val vatId: String? = null,
    val email: String? = null,
    val phone: String? = null,
    @SerialName("peppolId") val peppolId: String? = null,
    @SerialName("codiceFiscale") val codiceFiscale: String? = null,
    @SerialName("codiceDestinatario") val codiceDestinatario: String? = null,
    val pec: String? = null
)

/**
 * Rechnungsposition
 */
@Serializable
data class LineItem(
    val description: String,
    val quantity: Double,
    val unit: String = "C62",
    @SerialName("unitPrice") val unitPrice: Double,
    @SerialName("vatRate") val vatRate: Double = 19.0,
    val natura: String? = null
)

/**
 * Zahlungsinformationen
 */
@Serializable
data class PaymentInfo(
    val iban: String? = null,
    val bic: String? = null,
    val terms: String? = null,
    val reference: String? = null
)

/**
 * PDF-Anpassungsoptionen
 */
@Serializable
data class Customization(
    @SerialName("logoBase64") val logoBase64: String? = null,
    @SerialName("logoWidthMm") val logoWidthMm: Int? = null,
    @SerialName("footerText") val footerText: String? = null,
    @SerialName("accentColor") val accentColor: String? = null
)

/**
 * Vollstaendige Rechnungsdaten
 */
@Serializable
data class InvoiceData(
    val number: String,
    val date: String,
    @SerialName("dueDate") val dueDate: String? = null,
    val seller: Party,
    val buyer: Party,
    val items: List<LineItem>,
    val payment: PaymentInfo? = null,
    val currency: String = "EUR",
    val notes: String? = null,
    @SerialName("leitwegId") val leitwegId: String? = null,
    @SerialName("buyerReference") val buyerReference: String? = null,
    @SerialName("tipoDocumento") val tipoDocumento: String? = null
)

/**
 * Request-Payload fuer den Generate-Endpoint
 */
@Serializable
data class GenerateRequest(
    val template: String = "minimal",
    val locale: String = "en",
    val format: InvoiceFormat? = null,
    val profile: InvoiceProfile? = null,
    val invoice: InvoiceData,
    val customization: Customization? = null
)

/**
 * Validierungsergebnis der API
 */
@Serializable
data class ValidationResult(
    val status: String,
    val profile: String,
    val version: String,
    val warnings: List<String>? = null
)

/**
 * Kontoinformationen der API
 */
@Serializable
data class AccountInfo(
    val remaining: Int,
    val plan: String,
    @SerialName("overageCount") val overageCount: Int? = null,
    @SerialName("overageAllowed") val overageAllowed: Int? = null,
    val warning: String? = null
)

/**
 * Erfolgreiche Generate-API-Antwort
 */
@Serializable
data class GenerateResponse(
    @SerialName("pdf_base64") val pdfBase64: String,
    val filename: String,
    val validation: ValidationResult,
    val account: AccountInfo? = null
)

/**
 * Validierungsfehler-Detail
 */
@Serializable
data class ValidationError(
    val path: String,
    val code: String,
    val message: String,
    val severity: String = "error"
)

/**
 * Fehlerantwort der API
 */
@Serializable
data class ErrorResponse(
    val error: String,
    val message: String? = null,
    val details: List<ValidationError>? = null
)

// --- Retrieve-Typen ---

/**
 * Request-Payload fuer den Retrieve-Endpoint
 */
@Serializable
data class RetrieveRequest(
    @SerialName("data_base64") val dataBase64: String,
    @SerialName("content_type") val contentType: String? = null,
    @SerialName("include_source_xml") val includeSourceXml: Boolean = false
)

/**
 * Erkanntes Format aus dem Retrieve-Endpoint
 */
@Serializable
data class DetectedFormat(
    @SerialName("detected_format") val detectedFormat: String,
    val profile: String? = null,
    val version: String? = null,
    @SerialName("xml_type") val xmlType: String? = null,
    @SerialName("has_pdf") val hasPdf: Boolean = false
)

/**
 * Fehler aus dem Retrieve-Endpoint
 */
@Serializable
data class RetrieveError(
    val code: String,
    val message: String,
    val path: String? = null,
    val severity: String = "error"
)

/**
 * Antwort des Retrieve-Endpoints
 */
@Serializable
data class RetrieveResponse(
    val valid: Boolean,
    val format: DetectedFormat? = null,
    val invoice: InvoiceData? = null,
    @SerialName("source_xml_base64") val sourceXmlBase64: String? = null,
    @SerialName("transaction_id") val transactionId: String? = null,
    val errors: List<RetrieveError>? = null,
    val warnings: List<RetrieveError>? = null
)

/**
 * Validate-Endpoint Request
 */
@Serializable
data class ValidateRequest(
    val invoice: InvoiceData,
    val format: InvoiceFormat? = null,
    val profile: InvoiceProfile? = null
)

/**
 * Validate-Endpoint Response
 */
@Serializable
data class ValidateResponse(
    val valid: Boolean,
    val errors: List<ValidationError>? = null,
    val warnings: List<ValidationError>? = null,
    val profile: String? = null,
    val format: String? = null
)
