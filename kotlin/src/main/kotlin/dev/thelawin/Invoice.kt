package dev.thelawin

import java.io.File
import java.time.LocalDate
import java.time.format.DateTimeFormatter
import java.util.Base64

/**
 * Ergebnis einer Rechnungsgenerierung
 */
sealed class InvoiceResult {
    /**
     * Erfolgreiche Generierung
     */
    data class Success(
        val pdfBase64: String,
        val filename: String,
        val validation: ValidationResult,
        val account: AccountInfo? = null
    ) : InvoiceResult() {

        /**
         * PDF in Datei speichern
         */
        fun savePdf(path: String) {
            savePdf(File(path))
        }

        /**
         * PDF in Datei speichern
         */
        fun savePdf(file: File) {
            file.parentFile?.mkdirs()
            file.writeBytes(toBytes())
        }

        /**
         * PDF als ByteArray
         */
        fun toBytes(): ByteArray = Base64.getDecoder().decode(pdfBase64)

        /**
         * PDF als Data-URL
         */
        fun toDataUrl(): String = "data:application/pdf;base64,$pdfBase64"
    }

    /**
     * Fehlgeschlagene Generierung mit Validierungsfehlern
     */
    data class Failure(val errors: List<ValidationError>) : InvoiceResult()
}

/**
 * Prueft ob das Ergebnis erfolgreich ist
 */
val InvoiceResult.isSuccess: Boolean
    get() = this is InvoiceResult.Success

/**
 * Prueft ob das Ergebnis fehlgeschlagen ist
 */
val InvoiceResult.isFailure: Boolean
    get() = this is InvoiceResult.Failure

/**
 * DSL-Builder fuer Party
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
    var peppolId: String? = null
    var codiceFiscale: String? = null
    var codiceDestinatario: String? = null
    var pec: String? = null

    fun build(): Party = Party(
        name = name,
        street = street,
        city = city,
        postalCode = postalCode,
        country = country,
        vatId = vatId,
        email = email,
        phone = phone,
        peppolId = peppolId,
        codiceFiscale = codiceFiscale,
        codiceDestinatario = codiceDestinatario,
        pec = pec
    )
}

/**
 * DSL-Builder fuer LineItem
 */
class LineItemBuilder {
    var description: String = ""
    var quantity: Double = 1.0
    var unit: String = "C62"
    var unitPrice: Double = 0.0
    var vatRate: Double = 19.0
    var natura: String? = null

    fun build(): LineItem = LineItem(
        description = description,
        quantity = quantity,
        unit = unit,
        unitPrice = unitPrice,
        vatRate = vatRate,
        natura = natura
    )
}

/**
 * Fluent-Builder fuer die Rechnungserstellung
 */
class InvoiceBuilder internal constructor(private val client: ThelawinClient) {
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
    private var format: InvoiceFormat? = null
    private var profile: InvoiceProfile? = null
    private var logoBase64: String? = null
    private var logoWidthMm: Int? = null
    private var footerText: String? = null
    private var accentColor: String? = null
    private var notes: String? = null
    private var leitwegId: String? = null
    private var buyerReference: String? = null
    private var tipoDocumento: String? = null

    /**
     * Rechnungsnummer setzen
     */
    fun number(value: String): InvoiceBuilder {
        number = value
        return this
    }

    /**
     * Rechnungsdatum setzen (ISO-Format: YYYY-MM-DD)
     */
    fun date(value: String): InvoiceBuilder {
        date = value
        return this
    }

    /**
     * Rechnungsdatum aus LocalDate setzen
     */
    fun date(value: LocalDate): InvoiceBuilder {
        date = value.format(DateTimeFormatter.ISO_LOCAL_DATE)
        return this
    }

    /**
     * Faelligkeitsdatum setzen (ISO-Format: YYYY-MM-DD)
     */
    fun dueDate(value: String): InvoiceBuilder {
        dueDate = value
        return this
    }

    /**
     * Faelligkeitsdatum aus LocalDate setzen
     */
    fun dueDate(value: LocalDate): InvoiceBuilder {
        dueDate = value.format(DateTimeFormatter.ISO_LOCAL_DATE)
        return this
    }

    /**
     * Verkaeufer per DSL setzen
     */
    fun seller(block: PartyBuilder.() -> Unit): InvoiceBuilder {
        seller = PartyBuilder().apply(block).build()
        return this
    }

    /**
     * Verkaeufer als Party-Objekt setzen
     */
    fun seller(party: Party): InvoiceBuilder {
        seller = party
        return this
    }

    /**
     * Kaeufer per DSL setzen
     */
    fun buyer(block: PartyBuilder.() -> Unit): InvoiceBuilder {
        buyer = PartyBuilder().apply(block).build()
        return this
    }

    /**
     * Kaeufer als Party-Objekt setzen
     */
    fun buyer(party: Party): InvoiceBuilder {
        buyer = party
        return this
    }

    /**
     * Position per DSL hinzufuegen
     */
    fun addItem(block: LineItemBuilder.() -> Unit): InvoiceBuilder {
        items.add(LineItemBuilder().apply(block).build())
        return this
    }

    /**
     * Position als LineItem-Objekt hinzufuegen
     */
    fun addItem(item: LineItem): InvoiceBuilder {
        items.add(item)
        return this
    }

    /**
     * Alle Positionen auf einmal setzen
     */
    fun items(items: List<LineItem>): InvoiceBuilder {
        this.items.clear()
        this.items.addAll(items)
        return this
    }

    /**
     * Zahlungsinformationen setzen
     */
    fun payment(info: PaymentInfo): InvoiceBuilder {
        payment = info
        return this
    }

    /**
     * Zahlungsinformationen per Parameter setzen
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
     * Waehrung setzen (Standard: EUR)
     */
    fun currency(value: String): InvoiceBuilder {
        currency = value
        return this
    }

    /**
     * Template-Stil setzen
     */
    fun template(value: String): InvoiceBuilder {
        template = value
        return this
    }

    /**
     * Locale setzen
     */
    fun locale(value: String): InvoiceBuilder {
        locale = value
        return this
    }

    /**
     * Rechnungsformat setzen (zugferd, facturx, xrechnung, etc.)
     */
    fun format(value: InvoiceFormat): InvoiceBuilder {
        format = value
        return this
    }

    /**
     * ZUGFeRD/Factur-X Profilstufe setzen
     */
    fun profile(value: InvoiceProfile): InvoiceBuilder {
        profile = value
        return this
    }

    /**
     * Anmerkungen/Notizen setzen
     */
    fun notes(value: String): InvoiceBuilder {
        notes = value
        return this
    }

    /**
     * Leitweg-ID setzen (fuer XRechnung / deutsche B2G-Rechnungen)
     */
    fun leitwegId(value: String): InvoiceBuilder {
        leitwegId = value
        return this
    }

    /**
     * Buyer Reference setzen
     */
    fun buyerReference(value: String): InvoiceBuilder {
        buyerReference = value
        return this
    }

    /**
     * Tipo Documento setzen (fuer FatturaPA / italienische Rechnungen)
     */
    fun tipoDocumento(value: String): InvoiceBuilder {
        tipoDocumento = value
        return this
    }

    /**
     * Logo aus Datei setzen
     */
    fun logoFile(path: String, widthMm: Int? = null): InvoiceBuilder {
        return logoFile(File(path), widthMm)
    }

    /**
     * Logo aus Datei setzen
     */
    fun logoFile(file: File, widthMm: Int? = null): InvoiceBuilder {
        logoBase64 = Base64.getEncoder().encodeToString(file.readBytes())
        logoWidthMm = widthMm
        return this
    }

    /**
     * Logo als Base64-String setzen
     */
    fun logoBase64(base64: String, widthMm: Int? = null): InvoiceBuilder {
        logoBase64 = base64
        logoWidthMm = widthMm
        return this
    }

    /**
     * Fusszeile setzen
     */
    fun footerText(text: String): InvoiceBuilder {
        footerText = text
        return this
    }

    /**
     * Akzentfarbe setzen (Hex-Code)
     */
    fun accentColor(color: String): InvoiceBuilder {
        accentColor = color
        return this
    }

    /**
     * Rechnung generieren
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
            format = format,
            profile = profile,
            invoice = InvoiceData(
                number = number!!,
                date = date!!,
                dueDate = dueDate,
                seller = seller!!,
                buyer = buyer!!,
                items = items.toList(),
                payment = payment,
                currency = currency,
                notes = notes,
                leitwegId = leitwegId,
                buyerReference = buyerReference,
                tipoDocumento = tipoDocumento
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
