package dev.envoice

import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Base64

/**
 * Result of an invoice generation
 */
sealed class InvoiceResult {
    /**
     * Successful invoice generation
     */
    data class Success(
        val pdfBase64: String,
        val filename: String,
        val validation: ValidationResult,
        val account: AccountInfo? = null
    ) : InvoiceResult() {

        /**
         * Save the PDF to a file
         */
        fun savePdf(path: String) {
            savePdf(File(path))
        }

        /**
         * Save the PDF to a file
         */
        fun savePdf(file: File) {
            file.parentFile?.mkdirs()
            file.writeBytes(toBytes())
        }

        /**
         * Get the PDF as bytes
         */
        fun toBytes(): ByteArray = Base64.getDecoder().decode(pdfBase64)

        /**
         * Get the PDF as a data URL
         */
        fun toDataUrl(): String = "data:application/pdf;base64,$pdfBase64"
    }

    /**
     * Failed invoice generation with validation errors
     */
    data class Failure(val errors: List<ValidationError>) : InvoiceResult()
}

/**
 * Check if the result is successful
 */
val InvoiceResult.isSuccess: Boolean
    get() = this is InvoiceResult.Success

/**
 * Check if the result is a failure
 */
val InvoiceResult.isFailure: Boolean
    get() = this is InvoiceResult.Failure

/**
 * DSL builder for Party
 */
class PartyBuilder {
    var name: String = ""
    var street: String? = null
    var city: String? = null
    var postalCode: String? = null
    var country: String? = null
    var vatId: String? = null
    var email: String? = null
    var phone: String? = null

    fun build(): Party = Party(
        name = name,
        street = street,
        city = city,
        postalCode = postalCode,
        country = country,
        vatId = vatId,
        email = email,
        phone = phone
    )
}

/**
 * DSL builder for LineItem
 */
class LineItemBuilder {
    var description: String = ""
    var quantity: Double = 1.0
    var unit: String = "C62"
    var unitPrice: Double = 0.0
    var vatRate: Double = 19.0

    fun build(): LineItem = LineItem(
        description = description,
        quantity = quantity,
        unit = unit,
        unitPrice = unitPrice,
        vatRate = vatRate
    )
}

/**
 * Fluent builder for creating invoices
 */
class InvoiceBuilder internal constructor(private val client: EnvoiceClient) {
    private var number: String? = null
    private var date: String? = null
    private var dueDate: String? = null
    private var seller: Party? = null
    private var buyer: Party? = null
    private val items: MutableList<LineItem> = mutableListOf()
    private var payment: PaymentInfo? = null
    private var currency: String = "EUR"
    private var template: String = "minimal"
    private var locale: String = "en"
    private var logoBase64: String? = null
    private var logoWidthMm: Int? = null
    private var footerText: String? = null
    private var accentColor: String? = null

    /**
     * Set the invoice number
     */
    fun number(value: String): InvoiceBuilder {
        number = value
        return this
    }

    /**
     * Set the invoice date (ISO format: YYYY-MM-DD)
     */
    fun date(value: String): InvoiceBuilder {
        date = value
        return this
    }

    /**
     * Set the invoice date from LocalDate
     */
    fun date(value: LocalDate): InvoiceBuilder {
        date = value.format(DateTimeFormatter.ISO_LOCAL_DATE)
        return this
    }

    /**
     * Set the due date (ISO format: YYYY-MM-DD)
     */
    fun dueDate(value: String): InvoiceBuilder {
        dueDate = value
        return this
    }

    /**
     * Set the due date from LocalDate
     */
    fun dueDate(value: LocalDate): InvoiceBuilder {
        dueDate = value.format(DateTimeFormatter.ISO_LOCAL_DATE)
        return this
    }

    /**
     * Set the seller using DSL
     */
    fun seller(block: PartyBuilder.() -> Unit): InvoiceBuilder {
        seller = PartyBuilder().apply(block).build()
        return this
    }

    /**
     * Set the seller from Party object
     */
    fun seller(party: Party): InvoiceBuilder {
        seller = party
        return this
    }

    /**
     * Set the buyer using DSL
     */
    fun buyer(block: PartyBuilder.() -> Unit): InvoiceBuilder {
        buyer = PartyBuilder().apply(block).build()
        return this
    }

    /**
     * Set the buyer from Party object
     */
    fun buyer(party: Party): InvoiceBuilder {
        buyer = party
        return this
    }

    /**
     * Add a line item using DSL
     */
    fun addItem(block: LineItemBuilder.() -> Unit): InvoiceBuilder {
        items.add(LineItemBuilder().apply(block).build())
        return this
    }

    /**
     * Add a line item from LineItem object
     */
    fun addItem(item: LineItem): InvoiceBuilder {
        items.add(item)
        return this
    }

    /**
     * Set multiple items at once
     */
    fun items(items: List<LineItem>): InvoiceBuilder {
        this.items.clear()
        this.items.addAll(items)
        return this
    }

    /**
     * Set payment information
     */
    fun payment(info: PaymentInfo): InvoiceBuilder {
        payment = info
        return this
    }

    /**
     * Set payment information using builder
     */
    fun payment(
        iban: String? = null,
        bic: String? = null,
        terms: String? = null,
        reference: String? = null
    ): InvoiceBuilder {
        payment = PaymentInfo(iban, bic, terms, reference)
        return this
    }

    /**
     * Set the currency (default: EUR)
     */
    fun currency(value: String): InvoiceBuilder {
        currency = value
        return this
    }

    /**
     * Set the template style
     */
    fun template(value: String): InvoiceBuilder {
        template = value
        return this
    }

    /**
     * Set the locale
     */
    fun locale(value: String): InvoiceBuilder {
        locale = value
        return this
    }

    /**
     * Set logo from file
     */
    fun logoFile(path: String, widthMm: Int? = null): InvoiceBuilder {
        return logoFile(File(path), widthMm)
    }

    /**
     * Set logo from file
     */
    fun logoFile(file: File, widthMm: Int? = null): InvoiceBuilder {
        logoBase64 = Base64.getEncoder().encodeToString(file.readBytes())
        logoWidthMm = widthMm
        return this
    }

    /**
     * Set logo from Base64 string
     */
    fun logoBase64(base64: String, widthMm: Int? = null): InvoiceBuilder {
        logoBase64 = base64
        logoWidthMm = widthMm
        return this
    }

    /**
     * Set footer text
     */
    fun footerText(text: String): InvoiceBuilder {
        footerText = text
        return this
    }

    /**
     * Set accent color (hex code)
     */
    fun accentColor(color: String): InvoiceBuilder {
        accentColor = color
        return this
    }

    /**
     * Generate the invoice
     */
    suspend fun generate(): InvoiceResult {
        val errors = validateRequiredFields()
        if (errors.isNotEmpty()) {
            return InvoiceResult.Failure(errors)
        }

        val customization = if (logoBase64 != null || footerText != null || accentColor != null) {
            Customization(logoBase64, logoWidthMm, footerText, accentColor)
        } else null

        val request = GenerateRequest(
            template = template,
            locale = locale,
            invoice = InvoiceData(
                number = number!!,
                date = date!!,
                dueDate = dueDate,
                seller = seller!!,
                buyer = buyer!!,
                items = items.toList(),
                payment = payment,
                currency = currency
            ),
            customization = customization
        )

        return client.generateInvoice(request)
    }

    private fun validateRequiredFields(): List<ValidationError> {
        val errors = mutableListOf<ValidationError>()
        if (number == null) {
            errors.add(ValidationError("$.invoice.number", "REQUIRED", "Invoice number is required"))
        }
        if (date == null) {
            errors.add(ValidationError("$.invoice.date", "REQUIRED", "Invoice date is required"))
        }
        if (seller == null) {
            errors.add(ValidationError("$.invoice.seller", "REQUIRED", "Seller information is required"))
        }
        if (buyer == null) {
            errors.add(ValidationError("$.invoice.buyer", "REQUIRED", "Buyer information is required"))
        }
        if (items.isEmpty()) {
            errors.add(ValidationError("$.invoice.items", "REQUIRED", "At least one line item is required"))
        }
        return errors
    }
}
