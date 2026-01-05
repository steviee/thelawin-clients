package dev.envoice;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonInclude;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.List;

/**
 * Type definitions for the envoice SDK
 */
public final class Types {

    private Types() {}

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
        String phone
    ) {
        public Party(String name) {
            this(name, null, null, null, null, null, null, null);
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

            public Party build() {
                return new Party(name, street, city, postalCode, country, vatId, email, phone);
            }
        }
    }

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
        @JsonProperty("vatRate") double vatRate
    ) {
        public LineItem(String description, double quantity, double unitPrice) {
            this(description, quantity, "C62", unitPrice, 19.0);
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

            public Builder(String description) {
                this.description = description;
            }

            public Builder quantity(double quantity) { this.quantity = quantity; return this; }
            public Builder unit(String unit) { this.unit = unit; return this; }
            public Builder unitPrice(double unitPrice) { this.unitPrice = unitPrice; return this; }
            public Builder vatRate(double vatRate) { this.vatRate = vatRate; return this; }

            public LineItem build() {
                return new LineItem(description, quantity, unit, unitPrice, vatRate);
            }
        }
    }

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
        String currency
    ) {}

    /**
     * Generate request
     */
    @JsonInclude(JsonInclude.Include.NON_NULL)
    @JsonIgnoreProperties(ignoreUnknown = true)
    public record GenerateRequest(
        String template,
        String locale,
        InvoiceData invoice,
        Customization customization
    ) {}

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
}
