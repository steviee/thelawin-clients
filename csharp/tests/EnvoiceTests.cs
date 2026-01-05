using Xunit;
using Envoice;

namespace Envoice.Tests;

public class EnvoiceClientTests
{
    [Fact]
    public void Client_RequiresApiKey()
    {
        Assert.Throws<ArgumentException>(() => new EnvoiceClient(""));
        Assert.Throws<ArgumentException>(() => new EnvoiceClient("   "));
    }

    [Fact]
    public void Client_CreatesWithValidApiKey()
    {
        using var client = new EnvoiceClient("env_sandbox_test");
        Assert.NotNull(client);
    }

    [Fact]
    public void Invoice_ReturnsBuilder()
    {
        using var client = new EnvoiceClient("env_sandbox_test");
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
        using var client = new EnvoiceClient("env_sandbox_test");
        var result = await client.Invoice().GenerateAsync();

        Assert.False(result.IsSuccess);
        Assert.IsType<InvoiceFailure>(result);

        var failure = (InvoiceFailure)result;
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.number");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.date");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.seller");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.buyer");
        Assert.Contains(failure.Errors, e => e.Path == "$.invoice.items");
    }

    [Fact]
    public void Builder_FluentInterface()
    {
        using var client = new EnvoiceClient("env_sandbox_test");
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
    public void Builder_AcceptsPartyBuilders()
    {
        using var client = new EnvoiceClient("env_sandbox_test");

        var builder = client.Invoice()
            .Seller(s => s.Name("Acme GmbH").VatId("DE123456789").City("Berlin").Country("DE"))
            .Buyer(b => b.Name("Customer AG").City("München").Country("DE"));

        Assert.NotNull(builder);
    }

    [Fact]
    public void Builder_AcceptsLineItemBuilders()
    {
        using var client = new EnvoiceClient("env_sandbox_test");

        var builder = client.Invoice()
            .AddItem(i => i.Description("Consulting").Quantity(8).Unit("HUR").UnitPrice(150).VatRate(19));

        Assert.NotNull(builder);
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
        Assert.Equal("invoice-2026-001.pdf", success.Filename);
        Assert.Equal("EN16931", success.Validation.Profile);
        Assert.Equal(499, success.Account?.Remaining);

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
    }
}
