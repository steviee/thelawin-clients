package dev.envoice

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

/**
 * Party (seller or buyer) information
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
    val phone: String? = null
)

/**
 * Line item in an invoice
 */
@Serializable
data class LineItem(
    val description: String,
    val quantity: Double,
    val unit: String = "C62",
    @SerialName("unitPrice") val unitPrice: Double,
    @SerialName("vatRate") val vatRate: Double = 19.0
)

/**
 * Payment information
 */
@Serializable
data class PaymentInfo(
    val iban: String? = null,
    val bic: String? = null,
    val terms: String? = null,
    val reference: String? = null
)

/**
 * Customization options for the invoice PDF
 */
@Serializable
data class Customization(
    @SerialName("logoBase64") val logoBase64: String? = null,
    @SerialName("logoWidthMm") val logoWidthMm: Int? = null,
    @SerialName("footerText") val footerText: String? = null,
    @SerialName("accentColor") val accentColor: String? = null
)

/**
 * Complete invoice data structure
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
    val currency: String = "EUR"
)

/**
 * Request payload for the generate endpoint
 */
@Serializable
data class GenerateRequest(
    val template: String = "minimal",
    val locale: String = "en",
    val invoice: InvoiceData,
    val customization: Customization? = null
)

/**
 * Validation result from the API
 */
@Serializable
data class ValidationResult(
    val status: String,
    val profile: String,
    val version: String,
    val warnings: List<String>? = null
)

/**
 * Account information from the API
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
 * Successful API response
 */
@Serializable
data class GenerateResponse(
    @SerialName("pdf_base64") val pdfBase64: String,
    val filename: String,
    val validation: ValidationResult,
    val account: AccountInfo? = null
)

/**
 * Validation error detail
 */
@Serializable
data class ValidationError(
    val path: String,
    val code: String,
    val message: String,
    val severity: String = "error"
)

/**
 * Error response from the API
 */
@Serializable
data class ErrorResponse(
    val error: String,
    val message: String? = null,
    val details: List<ValidationError>? = null
)
