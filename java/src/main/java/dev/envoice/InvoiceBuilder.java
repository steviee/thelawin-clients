package dev.envoice;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.function.Consumer;

/**
 * Fluent builder for creating invoices
 */
public final class InvoiceBuilder {
    private final EnvoiceClient client;
    private String number;
    private String date;
    private String dueDate;
    private Types.Party seller;
    private Types.Party buyer;
    private final List<Types.LineItem> items = new ArrayList<>();
    private Types.PaymentInfo payment;
    private String currency = "EUR";
    private String template = "minimal";
    private String locale = "en";
    private String logoBase64;
    private Integer logoWidthMm;
    private String footerText;
    private String accentColor;

    InvoiceBuilder(EnvoiceClient client) {
        this.client = client;
    }

    /**
     * Set the invoice number
     */
    public InvoiceBuilder number(String value) {
        this.number = value;
        return this;
    }

    /**
     * Set the invoice date (ISO format: YYYY-MM-DD)
     */
    public InvoiceBuilder date(String value) {
        this.date = value;
        return this;
    }

    /**
     * Set the invoice date
     */
    public InvoiceBuilder date(LocalDate value) {
        this.date = value.format(DateTimeFormatter.ISO_LOCAL_DATE);
        return this;
    }

    /**
     * Set the due date (ISO format: YYYY-MM-DD)
     */
    public InvoiceBuilder dueDate(String value) {
        this.dueDate = value;
        return this;
    }

    /**
     * Set the due date
     */
    public InvoiceBuilder dueDate(LocalDate value) {
        this.dueDate = value.format(DateTimeFormatter.ISO_LOCAL_DATE);
        return this;
    }

    /**
     * Set the seller using builder
     */
    public InvoiceBuilder seller(Consumer<Types.Party.Builder> configurator) {
        var builder = new Types.Party.Builder("");
        configurator.accept(builder);
        this.seller = builder.build();
        return this;
    }

    /**
     * Set the seller
     */
    public InvoiceBuilder seller(Types.Party party) {
        this.seller = party;
        return this;
    }

    /**
     * Set the buyer using builder
     */
    public InvoiceBuilder buyer(Consumer<Types.Party.Builder> configurator) {
        var builder = new Types.Party.Builder("");
        configurator.accept(builder);
        this.buyer = builder.build();
        return this;
    }

    /**
     * Set the buyer
     */
    public InvoiceBuilder buyer(Types.Party party) {
        this.buyer = party;
        return this;
    }

    /**
     * Add a line item using builder
     */
    public InvoiceBuilder addItem(Consumer<Types.LineItem.Builder> configurator) {
        var builder = new Types.LineItem.Builder("");
        configurator.accept(builder);
        this.items.add(builder.build());
        return this;
    }

    /**
     * Add a line item
     */
    public InvoiceBuilder addItem(Types.LineItem item) {
        this.items.add(item);
        return this;
    }

    /**
     * Set multiple items at once
     */
    public InvoiceBuilder items(List<Types.LineItem> items) {
        this.items.clear();
        this.items.addAll(items);
        return this;
    }

    /**
     * Set payment information
     */
    public InvoiceBuilder payment(Types.PaymentInfo info) {
        this.payment = info;
        return this;
    }

    /**
     * Set the currency
     */
    public InvoiceBuilder currency(String value) {
        this.currency = value;
        return this;
    }

    /**
     * Set the template style
     */
    public InvoiceBuilder template(String value) {
        this.template = value;
        return this;
    }

    /**
     * Set the locale
     */
    public InvoiceBuilder locale(String value) {
        this.locale = value;
        return this;
    }

    /**
     * Set logo from file
     */
    public InvoiceBuilder logoFile(String path) throws IOException {
        return logoFile(Path.of(path), null);
    }

    /**
     * Set logo from file with width
     */
    public InvoiceBuilder logoFile(Path path, Integer widthMm) throws IOException {
        byte[] bytes = Files.readAllBytes(path);
        this.logoBase64 = Base64.getEncoder().encodeToString(bytes);
        this.logoWidthMm = widthMm;
        return this;
    }

    /**
     * Set logo from Base64 string
     */
    public InvoiceBuilder logoBase64(String base64, Integer widthMm) {
        this.logoBase64 = base64;
        this.logoWidthMm = widthMm;
        return this;
    }

    /**
     * Set footer text
     */
    public InvoiceBuilder footerText(String text) {
        this.footerText = text;
        return this;
    }

    /**
     * Set accent color
     */
    public InvoiceBuilder accentColor(String color) {
        this.accentColor = color;
        return this;
    }

    /**
     * Generate the invoice
     */
    public InvoiceResult generate() {
        var errors = validateRequiredFields();
        if (!errors.isEmpty()) {
            return new InvoiceResult.Failure(errors);
        }

        Types.Customization customization = null;
        if (logoBase64 != null || footerText != null || accentColor != null) {
            customization = new Types.Customization(logoBase64, logoWidthMm, footerText, accentColor);
        }

        var request = new Types.GenerateRequest(
            template,
            locale,
            new Types.InvoiceData(
                number,
                date,
                dueDate,
                seller,
                buyer,
                new ArrayList<>(items),
                payment,
                currency
            ),
            customization
        );

        return client.generateInvoice(request);
    }

    private List<Types.ValidationError> validateRequiredFields() {
        var errors = new ArrayList<Types.ValidationError>();
        if (number == null) {
            errors.add(new Types.ValidationError("$.invoice.number", "REQUIRED", "Invoice number is required", "error"));
        }
        if (date == null) {
            errors.add(new Types.ValidationError("$.invoice.date", "REQUIRED", "Invoice date is required", "error"));
        }
        if (seller == null) {
            errors.add(new Types.ValidationError("$.invoice.seller", "REQUIRED", "Seller information is required", "error"));
        }
        if (buyer == null) {
            errors.add(new Types.ValidationError("$.invoice.buyer", "REQUIRED", "Buyer information is required", "error"));
        }
        if (items.isEmpty()) {
            errors.add(new Types.ValidationError("$.invoice.items", "REQUIRED", "At least one line item is required", "error"));
        }
        return errors;
    }
}
