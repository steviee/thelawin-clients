namespace Envoice;

/// <summary>Result of an invoice generation</summary>
public abstract record InvoiceResult
{
    public abstract bool IsSuccess { get; }
    public bool IsFailure => !IsSuccess;
}

/// <summary>Successful invoice generation</summary>
public record InvoiceSuccess : InvoiceResult
{
    public string PdfBase64 { get; }
    public string Filename { get; }
    public ValidationResult Validation { get; }
    public AccountInfo? Account { get; }

    public override bool IsSuccess => true;

    public InvoiceSuccess(string pdfBase64, string filename, ValidationResult validation, AccountInfo? account = null)
    {
        PdfBase64 = pdfBase64;
        Filename = filename;
        Validation = validation;
        Account = account;
    }

    /// <summary>Save the PDF to a file</summary>
    public async Task SavePdfAsync(string path, CancellationToken cancellationToken = default)
    {
        var directory = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(directory))
        {
            Directory.CreateDirectory(directory);
        }
        await File.WriteAllBytesAsync(path, ToBytes(), cancellationToken);
    }

    /// <summary>Get the PDF as bytes</summary>
    public byte[] ToBytes() => Convert.FromBase64String(PdfBase64);

    /// <summary>Get the PDF as a data URL</summary>
    public string ToDataUrl() => $"data:application/pdf;base64,{PdfBase64}";
}

/// <summary>Failed invoice generation</summary>
public record InvoiceFailure : InvoiceResult
{
    public IReadOnlyList<ValidationError> Errors { get; }

    public override bool IsSuccess => false;

    public InvoiceFailure(IReadOnlyList<ValidationError> errors)
    {
        Errors = errors;
    }
}
