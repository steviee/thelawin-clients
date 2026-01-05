namespace Envoice;

/// <summary>Fluent builder for creating invoices</summary>
public class InvoiceBuilder
{
    private readonly EnvoiceClient _client;
    private string? _number;
    private string? _date;
    private string? _dueDate;
    private Party? _seller;
    private Party? _buyer;
    private readonly List<LineItem> _items = new();
    private PaymentInfo? _payment;
    private string _currency = "EUR";
    private string _template = "minimal";
    private string _locale = "en";
    private string? _logoBase64;
    private int? _logoWidthMm;
    private string? _footerText;
    private string? _accentColor;

    internal InvoiceBuilder(EnvoiceClient client) => _client = client;

    /// <summary>Set the invoice number</summary>
    public InvoiceBuilder Number(string value) { _number = value; return this; }

    /// <summary>Set the invoice date (YYYY-MM-DD)</summary>
    public InvoiceBuilder Date(string value) { _date = value; return this; }

    /// <summary>Set the invoice date</summary>
    public InvoiceBuilder Date(DateOnly value) { _date = value.ToString("yyyy-MM-dd"); return this; }

    /// <summary>Set the due date</summary>
    public InvoiceBuilder DueDate(string value) { _dueDate = value; return this; }

    /// <summary>Set the due date</summary>
    public InvoiceBuilder DueDate(DateOnly value) { _dueDate = value.ToString("yyyy-MM-dd"); return this; }

    /// <summary>Set the seller using builder</summary>
    public InvoiceBuilder Seller(Func<PartyBuilder, PartyBuilder> configure)
    {
        _seller = configure(new PartyBuilder()).Build();
        return this;
    }

    /// <summary>Set the seller</summary>
    public InvoiceBuilder Seller(Party party) { _seller = party; return this; }

    /// <summary>Set the buyer using builder</summary>
    public InvoiceBuilder Buyer(Func<PartyBuilder, PartyBuilder> configure)
    {
        _buyer = configure(new PartyBuilder()).Build();
        return this;
    }

    /// <summary>Set the buyer</summary>
    public InvoiceBuilder Buyer(Party party) { _buyer = party; return this; }

    /// <summary>Add a line item using builder</summary>
    public InvoiceBuilder AddItem(Func<LineItemBuilder, LineItemBuilder> configure)
    {
        _items.Add(configure(new LineItemBuilder()).Build());
        return this;
    }

    /// <summary>Add a line item</summary>
    public InvoiceBuilder AddItem(LineItem item) { _items.Add(item); return this; }

    /// <summary>Set multiple items at once</summary>
    public InvoiceBuilder Items(IEnumerable<LineItem> items)
    {
        _items.Clear();
        _items.AddRange(items);
        return this;
    }

    /// <summary>Set payment information</summary>
    public InvoiceBuilder Payment(PaymentInfo info) { _payment = info; return this; }

    /// <summary>Set the currency</summary>
    public InvoiceBuilder Currency(string value) { _currency = value; return this; }

    /// <summary>Set the template</summary>
    public InvoiceBuilder Template(string value) { _template = value; return this; }

    /// <summary>Set the locale</summary>
    public InvoiceBuilder Locale(string value) { _locale = value; return this; }

    /// <summary>Set logo from file</summary>
    public async Task<InvoiceBuilder> LogoFileAsync(string path, int? widthMm = null)
    {
        var bytes = await File.ReadAllBytesAsync(path);
        _logoBase64 = Convert.ToBase64String(bytes);
        _logoWidthMm = widthMm;
        return this;
    }

    /// <summary>Set logo from Base64</summary>
    public InvoiceBuilder LogoBase64(string base64, int? widthMm = null)
    {
        _logoBase64 = base64;
        _logoWidthMm = widthMm;
        return this;
    }

    /// <summary>Set footer text</summary>
    public InvoiceBuilder FooterText(string text) { _footerText = text; return this; }

    /// <summary>Set accent color</summary>
    public InvoiceBuilder AccentColor(string color) { _accentColor = color; return this; }

    /// <summary>Generate the invoice</summary>
    public async Task<InvoiceResult> GenerateAsync(CancellationToken cancellationToken = default)
    {
        var errors = ValidateRequiredFields();
        if (errors.Count > 0)
        {
            return new InvoiceFailure(errors);
        }

        var hasCustomization = _logoBase64 != null || _footerText != null || _accentColor != null;

        var request = new GenerateRequest(
            Template: _template,
            Locale: _locale,
            Invoice: new InvoiceData(
                Number: _number!,
                Date: _date!,
                DueDate: _dueDate,
                Seller: _seller!,
                Buyer: _buyer!,
                Items: _items.ToList(),
                Payment: _payment,
                Currency: _currency
            ),
            Customization: hasCustomization ? new Customization(_logoBase64, _logoWidthMm, _footerText, _accentColor) : null
        );

        return await _client.GenerateInvoiceAsync(request, cancellationToken);
    }

    private List<ValidationError> ValidateRequiredFields()
    {
        var errors = new List<ValidationError>();
        if (_number == null) errors.Add(new("$.invoice.number", "REQUIRED", "Invoice number is required"));
        if (_date == null) errors.Add(new("$.invoice.date", "REQUIRED", "Invoice date is required"));
        if (_seller == null) errors.Add(new("$.invoice.seller", "REQUIRED", "Seller information is required"));
        if (_buyer == null) errors.Add(new("$.invoice.buyer", "REQUIRED", "Buyer information is required"));
        if (_items.Count == 0) errors.Add(new("$.invoice.items", "REQUIRED", "At least one line item is required"));
        return errors;
    }
}

/// <summary>Builder for Party</summary>
public class PartyBuilder
{
    private string _name = "";
    private string? _street, _city, _postalCode, _country, _vatId, _email, _phone;

    public PartyBuilder Name(string value) { _name = value; return this; }
    public PartyBuilder Street(string value) { _street = value; return this; }
    public PartyBuilder City(string value) { _city = value; return this; }
    public PartyBuilder PostalCode(string value) { _postalCode = value; return this; }
    public PartyBuilder Country(string value) { _country = value; return this; }
    public PartyBuilder VatId(string value) { _vatId = value; return this; }
    public PartyBuilder Email(string value) { _email = value; return this; }
    public PartyBuilder Phone(string value) { _phone = value; return this; }

    public Party Build() => new(_name, _street, _city, _postalCode, _country, _vatId, _email, _phone);
}

/// <summary>Builder for LineItem</summary>
public class LineItemBuilder
{
    private string _description = "";
    private double _quantity = 1;
    private string _unit = "C62";
    private double _unitPrice;
    private double _vatRate = 19.0;

    public LineItemBuilder Description(string value) { _description = value; return this; }
    public LineItemBuilder Quantity(double value) { _quantity = value; return this; }
    public LineItemBuilder Unit(string value) { _unit = value; return this; }
    public LineItemBuilder UnitPrice(double value) { _unitPrice = value; return this; }
    public LineItemBuilder VatRate(double value) { _vatRate = value; return this; }

    public LineItem Build() => new(_description, _quantity, _unit, _unitPrice, _vatRate);
}
