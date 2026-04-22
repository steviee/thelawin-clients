package dev.thelawin;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Type definitions for the thelawin SDK
 */
public final class Types {

    private Types() {}

    // ── Enums ────────────────────────────────────────────────────────────

    /**
     * Supported invoice output formats
     */
    public enum InvoiceFormat {
        AUTO("auto"),
        ZUGFERD("zugferd"),
        FACTURX("facturx"),
        XRECHNUNG("xrechnung"),
        UBL("ubl"),
        CII("cii"),
        PEPPOL("peppol"),
        FATTURAPA("fatturapa"),
        PDF("pdf");

        private final String value;

        InvoiceFormat(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }

        @Override
        public String toString() {
            return value;
        }
    }

    /**
     * Supported invoice profiles
     */
    public enum InvoiceProfile {
        MINIMUM("minimum"),
        BASIC_WL("basicwl"),
        BASIC("basic"),
        EN16931("en16931"),
        EXTENDED("extended"),
        XRECHNUNG("xrechnung");

        private final String value;

        InvoiceProfile(String value) {
            this.value = value;
        }

        public String getValue() {
            return value;
        }

        @Override
        public String toString() {
            return value;
        }
    }

    // ── Party ────────────────────────────────────────────────────────────

    /**
     * Party (seller or buyer) information
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Party(
        String name,
        String street,
        String city,
        @JsonProperty("postalCode") String postalCode,
        String country,
        @JsonProperty("vatId") String vatId,
        String email,
        String phone,
        @JsonProperty("peppolId") String peppolId,
        @JsonProperty("codiceFiscale") String codiceFiscale,
        @JsonProperty("codiceDestinatario") String codiceDestinatario,
        String pec
    ) {
        public Party(String name) {
            this(name, null, null, null, null, null, null, null, null, null, null, null);
        }

        public static Builder builder(String name) {
            return new Builder(name);
        }

        public static class Builder {
            private final String name;
            private String street;
            private String city;
            private String postalCode;
            private String country;
            private String vatId;
            private String email;
            private String phone;
            private String peppolId;
            private String codiceFiscale;
            private String codiceDestinatario;
            private String pec;

            public Builder(String name) {
                this.name = name;
            }

            public Builder street(String street) { this.street = street; return this; }
            public Builder city(String city) { this.city = city; return this; }
            public Builder postalCode(String postalCode) { this.postalCode = postalCode; return this; }
            public Builder country(String country) { this.country = country; return this; }
            public Builder vatId(String vatId) { this.vatId = vatId; return this; }
            public Builder email(String email) { this.email = email; return this; }
            public Builder phone(String phone) { this.phone = phone; return this; }
            public Builder peppolId(String peppolId) { this.peppolId = peppolId; return this; }
            public Builder codiceFiscale(String codiceFiscale) { this.codiceFiscale = codiceFiscale; return this; }
            public Builder codiceDestinatario(String codiceDestinatario) { this.codiceDestinatario = codiceDestinatario; return this; }
            public Builder pec(String pec) { this.pec = pec; return this; }

            public Party build() {
                return new Party(name, street, city, postalCode, country, vatId,
                    email, phone, peppolId, codiceFiscale, codiceDestinatario, pec);
            }
        }
    }

    // ── LineItem ─────────────────────────────────────────────────────────

    /**
     * Line item in an invoice
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record LineItem(
        String description,
        double quantity,
        String unit,
        @JsonProperty("unitPrice") double unitPrice,
        @JsonProperty("vatRate") double vatRate,
        String natura
    ) {
        public LineItem(String description, double quantity, double unitPrice) {
            this(description, quantity, "C62", unitPrice, 19.0, null);
        }

        public static Builder builder(String description) {
            return new Builder(description);
        }

        public static class Builder {
            private final String description;
            private double quantity = 1.0;
            private String unit = "C62";
            private double unitPrice;
            private double vatRate = 19.0;
            private String natura;

            public Builder(String description) {
                this.description = description;
            }

            public Builder quantity(double quantity) { this.quantity = quantity; return this; }
            public Builder unit(String unit) { this.unit = unit; return this; }
            public Builder unitPrice(double unitPrice) { this.unitPrice = unitPrice; return this; }
            public Builder vatRate(double vatRate) { this.vatRate = vatRate; return this; }
            public Builder natura(String natura) { this.natura = natura; return this; }

            public LineItem build() {
                return new LineItem(description, quantity, unit, unitPrice, vatRate, natura);
            }
        }
    }

    // ── Payment / Customization ──────────────────────────────────────────

    /**
     * Payment information
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record PaymentInfo(
        String iban,
        String bic,
        String terms,
        String reference
    ) {}

    /**
     * Customization options
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record Customization(
        @JsonProperty("logoBase64") String logoBase64,
        @JsonProperty("logoWidthMm") Integer logoWidthMm,
        @JsonProperty("footerText") String footerText,
        @JsonProperty("accentColor") String accentColor
    ) {}

    // ── InvoiceData ──────────────────────────────────────────────────────

    /**
     * Complete invoice data
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record InvoiceData(
        String number,
        String date,
        @JsonProperty("dueDate") String dueDate,
        Party seller,
        Party buyer,
        List<LineItem> items,
        PaymentInfo payment,
        String currency,
        String notes,
        @JsonProperty("leitwegId") String leitwegId,
        @JsonProperty("buyerReference") String buyerReference,
        @JsonProperty("tipoDocumento") String tipoDocumento
    ) {
        /**
         * Convenience constructor without new fields (backward-compatible)
         */
        public InvoiceData(String number, String date, String dueDate,
                           Party seller, Party buyer, List<LineItem> items,
                           PaymentInfo payment, String currency) {
            this(number, date, dueDate, seller, buyer, items, payment, currency,
                null, null, null, null);
        }
    }

    // ── Request / Response types ─────────────────────────────────────────

    /**
     * Generate request
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record GenerateRequest(
        String format,
        String profile,
        String template,
        String locale,
        InvoiceData invoice,
        Customization customization
    ) {
        /**
         * Convenience constructor without format/profile (backward-compatible)
         */
        public GenerateRequest(String template, String locale, InvoiceData invoice,
                               Customization customization) {
            this(null, null, template, locale, invoice, customization);
        }
    }

    /**
     * Validation result
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ValidationResult(
        String status,
        String profile,
        String version,
        List<String> warnings
    ) {}

    /**
     * Account info
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record AccountInfo(
        int remaining,
        String plan,
        @JsonProperty("overageCount") Integer overageCount,
        @JsonProperty("overageAllowed") Integer overageAllowed,
        String warning
    ) {}

    /**
     * Generate response
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record GenerateResponse(
        @JsonProperty("pdf_base64") String pdfBase64,
        String filename,
        ValidationResult validation,
        AccountInfo account
    ) {}

    /**
     * Validation error
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ValidationError(
        String path,
        String code,
        String message,
        String severity
    ) {}

    /**
     * Error response
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record ErrorResponse(
        String error,
        String message,
        List<ValidationError> details
    ) {}

    // ── Retrieve types ───────────────────────────────────────────────────

    /**
     * Request payload for /v1/retrieve
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record RetrieveRequest(
        @JsonProperty("data_base64") String dataBase64,
        @JsonProperty("content_type") String contentType,
        @JsonProperty("include_source_xml") boolean includeSourceXml
    ) {}

    /**
     * Detected format information returned by /v1/retrieve
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record DetectedFormat(
        @JsonProperty("detectedFormat") String detectedFormat,
        String profile,
        String version,
        @JsonProperty("xmlType") String xmlType,
        @JsonProperty("hasPdf") boolean hasPdf
    ) {}

    /**
     * Error detail from retrieve response
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record RetrieveError(
        String code,
        String message,
        String path,
        String severity
    ) {}

    /**
     * Response from /v1/retrieve
     */
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record RetrieveResponse(
        boolean valid,
        DetectedFormat format,
        InvoiceData invoice,
        @JsonProperty("source_xml_base64") String sourceXmlBase64,
        @JsonProperty("transaction_id") String transactionId,
        List<RetrieveError> errors,
        List<RetrieveError> warnings
    ) {}
}
