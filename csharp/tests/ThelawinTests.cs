using Xunit;
using Thelawin;

namespace Thelawin.Tests;

public class ThelawinClientTests
{
    [Fact]
    public void Client_RequiresApiKey()
    {
        Assert.Throws<ArgumentException>(() => new ThelawinClient(""));
        Assert.Throws<ArgumentException>(() => new ThelawinClient("   "));
    }

    [Fact]
    public void Client_ThrowsOnNullApiKey()
    {
        Assert.Throws<ArgumentException>(() => new ThelawinClient(null!));
    }

    [Fact]
    public void Client_CreatesWithValidApiKey()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        Assert.NotNull(client);
    }

    [Fact]
    public void Client_AcceptsCustomUrl()
    {
        using var client = new ThelawinClient("tl_sandbox_test", apiUrl: "https://custom.api.local");
        Assert.NotNull(client);
    }

    [Fact]
    public void Client_AcceptsCustomTimeout()
    {
        using var client = new ThelawinClient("tl_sandbox_test", timeout: TimeSpan.FromSeconds(60));
        Assert.NotNull(client);
    }

    [Fact]
    public void Client_AcceptsExternalHttpClient()
    {
        using var httpClient = new HttpClient();
        using var client = new ThelawinClient("tl_sandbox_test", httpClient: httpClient);
        Assert.NotNull(client);
    }

    [Fact]
    public void Invoice_ReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();
        Assert.NotNull(builder);
        Assert.IsType<InvoiceBuilder>(builder);
    }
}

public class InvoiceBuilderTests
{
    [Fact]
    public async Task Builder_ValidatesRequiredFields()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var result = await client.Invoice().GenerateAsync();

        Assert.False(result.IsSuccess);
        Assert.IsType<InvoiceFailure>(result);

        var failure = (InvoiceFailure)result;
        Assert.Equal(5, failure.Errors.Count);
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.number");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.date");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.seller");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.buyer");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.items");
    }

    [Fact]
    public async Task Builder_ValidatesPartialFields()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var result = await client.Invoice()
            .Number("2026-001")
            .Date("2026-01-15")
            .GenerateAsync();

        Assert.False(result.IsSuccess);
        var failure = (InvoiceFailure)result;
        Assert.Equal(3, failure.Errors.Count);
        Assert.DoesNotContain(failure.Errors, e => e.Path == "$.invoice.number");
        Assert.DoesNotContain(failure.Errors, e => e.Path == "$.invoice.date");
    }

    [Fact]
    public void Builder_FluentInterface()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();

        Assert.Same(builder, builder.Number("2026-001"));
        Assert.Same(builder, builder.Date("2026-01-15"));
        Assert.Same(builder, builder.DueDate("2026-02-15"));
        Assert.Same(builder, builder.Currency("EUR"));
        Assert.Same(builder, builder.Template("minimal"));
        Assert.Same(builder, builder.Locale("de"));
        Assert.Same(builder, builder.FooterText("Thanks!"));
        Assert.Same(builder, builder.AccentColor("#8b5cf6"));
    }

    [Fact]
    public void Builder_FormatReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();

        Assert.Same(builder, builder.Format(InvoiceFormat.Zugferd));
        Assert.Same(builder, builder.Format(InvoiceFormat.Facturx));
        Assert.Same(builder, builder.Format(InvoiceFormat.Xrechnung));
        Assert.Same(builder, builder.Format(InvoiceFormat.Peppol));
        Assert.Same(builder, builder.Format(InvoiceFormat.Fatturapa));
        Assert.Same(builder, builder.Format(InvoiceFormat.Ubl));
        Assert.Same(builder, builder.Format(InvoiceFormat.Cii));
        Assert.Same(builder, builder.Format(InvoiceFormat.Pdf));
        Assert.Same(builder, builder.Format(InvoiceFormat.Auto));
    }

    [Fact]
    public void Builder_ProfileReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();

        Assert.Same(builder, builder.Profile(InvoiceProfile.Minimum));
        Assert.Same(builder, builder.Profile(InvoiceProfile.BasicWl));
        Assert.Same(builder, builder.Profile(InvoiceProfile.Basic));
        Assert.Same(builder, builder.Profile(InvoiceProfile.En16931));
        Assert.Same(builder, builder.Profile(InvoiceProfile.Extended));
        Assert.Same(builder, builder.Profile(InvoiceProfile.Xrechnung));
    }

    [Fact]
    public void Builder_NotesReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();
        Assert.Same(builder, builder.Notes("Payment within 30 days"));
    }

    [Fact]
    public void Builder_LeitwegIdReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();
        Assert.Same(builder, builder.LeitwegId("04011000-1234512345-06"));
    }

    [Fact]
    public void Builder_BuyerReferenceReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();
        Assert.Same(builder, builder.BuyerReference("PO-2026-42"));
    }

    [Fact]
    public void Builder_TipoDocumentoReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();
        Assert.Same(builder, builder.TipoDocumento("TD01"));
    }

    [Fact]
    public void Builder_AcceptsPartyBuilders()
    {
        using var client = new ThelawinClient("tl_sandbox_test");

        var builder = client.Invoice()
            .Seller(s => s.Name("Acme GmbH").VatId("DE123456789").City("Berlin").Country("DE"))
            .Buyer(b => b.Name("Customer AG").City("Muenchen").Country("DE"));

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsPartyWithPeppolFields()
    {
        using var client = new ThelawinClient("tl_sandbox_test");

        var builder = client.Invoice()
            .Seller(s => s
                .Name("Peppol Seller AS")
                .Country("NO")
                .VatId("NO999888777")
                .EndpointId("9908:999888777")
                .EndpointScheme("0088"))
            .Buyer(b => b
                .Name("Peppol Buyer AB")
                .Country("SE")
                .EndpointId("0007:1234567890")
                .EndpointScheme("0007"));

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsPartyWithFatturaPaFields()
    {
        using var client = new ThelawinClient("tl_sandbox_test");

        var builder = client.Invoice()
            .Seller(s => s
                .Name("Azienda Italiana SRL")
                .Country("IT")
                .VatId("IT12345678901")
                .CodiceFiscale("RSSMRA85M01H501Z")
                .PecEmail("azienda@pec.it"))
            .Buyer(b => b
                .Name("Cliente Italiano SRL")
                .Country("IT")
                .CodiceDestinatario("ABC1234")
                .CodiceFiscale("BNCRSS90A01F205X"));

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsLineItemBuilders()
    {
        using var client = new ThelawinClient("tl_sandbox_test");

        var builder = client.Invoice()
            .AddItem(i => i.Description("Consulting").Quantity(8).Unit("HUR").UnitPrice(150).VatRate(19));

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsLineItemWithNatura()
    {
        using var client = new ThelawinClient("tl_sandbox_test");

        var builder = client.Invoice()
            .AddItem(i => i.Description("EU Service").Quantity(1).UnitPrice(1000).VatRate(0).Natura("N2.2"));

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsDirectParty()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var seller = new Party("Direct Seller GmbH", Country: "DE", VatId: "DE999888777");
        var builder = client.Invoice().Seller(seller);
        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsDirectLineItem()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var item = new LineItem("Widget", 10, UnitPrice: 5.99, VatRate: 19.0);
        var builder = client.Invoice().AddItem(item);
        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_SetItemsReplacesExisting()
    {
        using var client = new ThelawinClient("tl_sandbox_test");

        var builder = client.Invoice()
            .AddItem(i => i.Description("Old item").UnitPrice(10))
            .Items(new[]
            {
                new LineItem("New item 1", 1, UnitPrice: 20),
                new LineItem("New item 2", 2, UnitPrice: 30)
            });

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsDateOnly()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice()
            .Date(new DateOnly(2026, 4, 22))
            .DueDate(new DateOnly(2026, 5, 22));
        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_LogoBase64ReturnsBuilder()
    {
        using var client = new ThelawinClient("tl_sandbox_test");
        var builder = client.Invoice();
        Assert.Same(builder, builder.LogoBase64("iVBORw0KGgo=", widthMm: 40));
    }
}

public class PartyBuilderTests
{
    [Fact]
    public void PartyBuilder_BuildsCompleteParty()
    {
        var party = new PartyBuilder()
            .Name("Full Party GmbH")
            .Street("Hauptstr. 1")
            .City("Berlin")
            .PostalCode("10115")
            .Country("DE")
            .VatId("DE123456789")
            .Email("info@example.de")
            .Phone("+49 30 12345")
            .Build();

        Assert.Equal("Full Party GmbH", party.Name);
        Assert.Equal("Hauptstr. 1", party.Street);
        Assert.Equal("Berlin", party.City);
        Assert.Equal("10115", party.PostalCode);
        Assert.Equal("DE", party.Country);
        Assert.Equal("DE123456789", party.VatId);
        Assert.Equal("info@example.de", party.Email);
        Assert.Equal("+49 30 12345", party.Phone);
    }

    [Fact]
    public void PartyBuilder_BuildsPartyWithPeppolFields()
    {
        var party = new PartyBuilder()
            .Name("Peppol Corp")
            .EndpointId("9908:123456789")
            .EndpointScheme("0088")
            .Build();

        Assert.Equal("Peppol Corp", party.Name);
        Assert.Equal("9908:123456789", party.EndpointId);
        Assert.Equal("0088", party.EndpointScheme);
    }

    [Fact]
    public void PartyBuilder_BuildsPartyWithFatturaPaFields()
    {
        var party = new PartyBuilder()
            .Name("Ditta Italiana")
            .CodiceFiscale("RSSMRA85M01H501Z")
            .CodiceDestinatario("0000000")
            .PecEmail("ditta@pec.it")
            .Build();

        Assert.Equal("Ditta Italiana", party.Name);
        Assert.Equal("RSSMRA85M01H501Z", party.CodiceFiscale);
        Assert.Equal("0000000", party.CodiceDestinatario);
        Assert.Equal("ditta@pec.it", party.PecEmail);
    }
}

public class InvoiceResultTests
{
    [Fact]
    public void Success_ProvidesCorrectData()
    {
        var success = new InvoiceSuccess(
            pdfBase64: "JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK",
            filename: "invoice-2026-001.pdf",
            validation: new ValidationResult("valid", "EN16931", "2.3.2"),
            account: new AccountInfo(499, "starter")
        );

        Assert.True(success.IsSuccess);
        Assert.False(success.IsFailure);
        Assert.Equal("invoice-2026-001.pdf", success.Filename);
        Assert.Equal("EN16931", success.Validation.Profile);
        Assert.Equal(499, success.Account?.Remaining);
        Assert.Equal("starter", success.Account?.Plan);

        var bytes = success.ToBytes();
        Assert.NotEmpty(bytes);
        Assert.StartsWith("%PDF", System.Text.Encoding.UTF8.GetString(bytes[..4]));

        var dataUrl = success.ToDataUrl();
        Assert.StartsWith("data:application/pdf;base64,", dataUrl);
    }

    [Fact]
    public void Failure_ContainsErrors()
    {
        var failure = new InvoiceFailure(new List<ValidationError>
        {
            new("$.invoice.number", "REQUIRED", "Invoice number is required")
        });

        Assert.False(failure.IsSuccess);
        Assert.True(failure.IsFailure);
        Assert.Single(failure.Errors);
        Assert.Equal("$.invoice.number", failure.Errors[0].Path);
        Assert.Equal("REQUIRED", failure.Errors[0].Code);
        Assert.Equal("Invoice number is required", failure.Errors[0].Message);
    }

    [Fact]
    public void Failure_MultipleErrors()
    {
        var failure = new InvoiceFailure(new List<ValidationError>
        {
            new("$.invoice.number", "REQUIRED", "Invoice number is required"),
            new("$.invoice.seller", "REQUIRED", "Seller information is required"),
            new("$.invoice.items", "REQUIRED", "At least one line item is required")
        });

        Assert.Equal(3, failure.Errors.Count);
    }
}

public class TypesTests
{
    [Fact]
    public void InvoiceFormat_HasAllValues()
    {
        var values = Enum.GetValues<InvoiceFormat>();
        Assert.Equal(9, values.Length);
        Assert.Contains(InvoiceFormat.Auto, values);
        Assert.Contains(InvoiceFormat.Zugferd, values);
        Assert.Contains(InvoiceFormat.Facturx, values);
        Assert.Contains(InvoiceFormat.Xrechnung, values);
        Assert.Contains(InvoiceFormat.Ubl, values);
        Assert.Contains(InvoiceFormat.Cii, values);
        Assert.Contains(InvoiceFormat.Peppol, values);
        Assert.Contains(InvoiceFormat.Fatturapa, values);
        Assert.Contains(InvoiceFormat.Pdf, values);
    }

    [Fact]
    public void InvoiceProfile_HasAllValues()
    {
        var values = Enum.GetValues<InvoiceProfile>();
        Assert.Equal(6, values.Length);
        Assert.Contains(InvoiceProfile.Minimum, values);
        Assert.Contains(InvoiceProfile.BasicWl, values);
        Assert.Contains(InvoiceProfile.Basic, values);
        Assert.Contains(InvoiceProfile.En16931, values);
        Assert.Contains(InvoiceProfile.Extended, values);
        Assert.Contains(InvoiceProfile.Xrechnung, values);
    }

    [Fact]
    public void Party_SupportsAllFields()
    {
        var party = new Party(
            "Test Corp",
            Street: "123 Main St",
            City: "Berlin",
            PostalCode: "10115",
            Country: "DE",
            VatId: "DE123456789",
            Email: "test@test.de",
            Phone: "+49 30 123",
            EndpointId: "0088:1234567890",
            EndpointScheme: "0088",
            CodiceFiscale: "RSSMRA85M01H501Z",
            CodiceDestinatario: "ABC1234",
            PecEmail: "test@pec.it"
        );

        Assert.Equal("Test Corp", party.Name);
        Assert.Equal("0088:1234567890", party.EndpointId);
        Assert.Equal("0088", party.EndpointScheme);
        Assert.Equal("RSSMRA85M01H501Z", party.CodiceFiscale);
        Assert.Equal("ABC1234", party.CodiceDestinatario);
        Assert.Equal("test@pec.it", party.PecEmail);
    }

    [Fact]
    public void LineItem_SupportsNatura()
    {
        var item = new LineItem("Exempt service", 1, UnitPrice: 500, VatRate: 0, Natura: "N2.2");
        Assert.Equal("N2.2", item.Natura);
        Assert.Equal(0, item.VatRate);
    }

    [Fact]
    public void DetectedFormat_SupportsAllFields()
    {
        var format = new DetectedFormat("zugferd", Profile: "EN16931", Version: "2.3.2");
        Assert.Equal("zugferd", format.Format);
        Assert.Equal("EN16931", format.Profile);
        Assert.Equal("2.3.2", format.Version);
    }

    [Fact]
    public void RetrieveError_SupportsFields()
    {
        var error = new RetrieveError("PARSE_ERROR", "Could not parse PDF");
        Assert.Equal("PARSE_ERROR", error.Code);
        Assert.Equal("Could not parse PDF", error.Message);
    }

    [Fact]
    public void RetrieveResponse_SuccessCase()
    {
        var response = new RetrieveResponse(
            Success: true,
            DetectedFormat: new DetectedFormat("zugferd", "EN16931", "2.3.2"),
            Invoice: new InvoiceData(
                "INV-001", "2026-01-15", "2026-02-15",
                new Party("Seller"), new Party("Buyer"),
                new List<LineItem> { new("Item", 1, UnitPrice: 100) }
            ),
            SourceXml: "<xml/>",
            Account: new AccountInfo(99, "starter")
        );

        Assert.True(response.Success);
        Assert.NotNull(response.DetectedFormat);
        Assert.NotNull(response.Invoice);
        Assert.Equal("<xml/>", response.SourceXml);
        Assert.Equal(99, response.Account?.Remaining);
    }

    [Fact]
    public void RetrieveResponse_ErrorCase()
    {
        var response = new RetrieveResponse(
            Success: false,
            Errors: new List<RetrieveError>
            {
                new("UNSUPPORTED_FORMAT", "Format not recognized")
            }
        );

        Assert.False(response.Success);
        Assert.NotNull(response.Errors);
        Assert.Single(response.Errors);
    }

    [Fact]
    public void ValidationResult_SupportsWarnings()
    {
        var result = new ValidationResult("valid", "EN16931", "2.3.2",
            Warnings: new List<string> { "BT-30 recommended", "BT-34 missing" });

        Assert.Equal("valid", result.Status);
        Assert.Equal(2, result.Warnings?.Count);
    }

    [Fact]
    public void AccountInfo_SupportsOverage()
    {
        var info = new AccountInfo(0, "starter", OverageCount: 5, OverageAllowed: 75, Warning: "Quota exceeded");
        Assert.Equal(0, info.Remaining);
        Assert.Equal(5, info.OverageCount);
        Assert.Equal(75, info.OverageAllowed);
        Assert.Equal("Quota exceeded", info.Warning);
    }

    [Fact]
    public void InvoiceData_SupportsExtendedFields()
    {
        var data = new InvoiceData(
            "INV-2026-001", "2026-04-22", "2026-05-22",
            new Party("Seller"), new Party("Buyer"),
            new List<LineItem> { new("Service", 1, UnitPrice: 100) },
            Currency: "EUR",
            Notes: "Payment within 30 days",
            LeitwegId: "04011000-1234512345-06",
            BuyerReference: "PO-2026-42",
            TipoDocumento: "TD01"
        );

        Assert.Equal("Payment within 30 days", data.Notes);
        Assert.Equal("04011000-1234512345-06", data.LeitwegId);
        Assert.Equal("PO-2026-42", data.BuyerReference);
        Assert.Equal("TD01", data.TipoDocumento);
    }
}

public class ExceptionTests
{
    [Fact]
    public void ThelawinException_HasMessage()
    {
        var ex = new ThelawinException("test error");
        Assert.Equal("test error", ex.Message);
    }

    [Fact]
    public void ThelawinApiException_HasStatusAndCode()
    {
        var ex = new ThelawinApiException("Not found", 404, "not_found");
        Assert.Equal("Not found", ex.Message);
        Assert.Equal(404, ex.StatusCode);
        Assert.Equal("not_found", ex.Code);
    }

    [Fact]
    public void ThelawinQuotaExceededException_Is402()
    {
        var ex = new ThelawinQuotaExceededException("No credits left");
        Assert.Equal(402, ex.StatusCode);
        Assert.Equal("quota_exceeded", ex.Code);
        Assert.Equal("No credits left", ex.Message);
    }

    [Fact]
    public void ThelawinNetworkException_WrapsInner()
    {
        var inner = new HttpRequestException("Connection refused");
        var ex = new ThelawinNetworkException("Network error", inner);
        Assert.Equal("Network error", ex.Message);
        Assert.Same(inner, ex.InnerException);
    }

    [Fact]
    public void ThelawinValidationException_FormatsErrors()
    {
        var errors = new List<ValidationError>
        {
            new("$.invoice.number", "REQUIRED", "Number is required"),
            new("$.invoice.seller.vatId", "INVALID", "Invalid VAT ID")
        };
        var ex = new ThelawinValidationException(errors);

        Assert.Equal(2, ex.Errors.Count);
        Assert.Equal(422, ex.StatusCode);
        Assert.Contains("Number is required", ex.Message);
        Assert.Contains("Invalid VAT ID", ex.ToUserMessage());
    }
}
