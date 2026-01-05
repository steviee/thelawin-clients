namespace Envoice;

/// <summary>Base exception for all envoice SDK errors</summary>
public class EnvoiceException : Exception
{
    public EnvoiceException(string message) : base(message) { }
    public EnvoiceException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>Exception thrown when the API returns validation errors</summary>
public class EnvoiceValidationException : EnvoiceException
{
    public IReadOnlyList<ValidationError> Errors { get; }
    public int StatusCode { get; }

    public EnvoiceValidationException(IReadOnlyList<ValidationError> errors, int statusCode = 422)
        : base($"Validation failed: {string.Join("; ", errors.Select(e => $"{e.Path}: {e.Message}"))}")
    {
        Errors = errors;
        StatusCode = statusCode;
    }

    public string ToUserMessage() => string.Join("\n", Errors.Select(e => $"- {e.Path}: {e.Message}"));
}

/// <summary>Exception thrown when the API returns an HTTP error</summary>
public class EnvoiceApiException : EnvoiceException
{
    public int StatusCode { get; }
    public string? Code { get; }

    public EnvoiceApiException(string message, int statusCode, string? code = null) : base(message)
    {
        StatusCode = statusCode;
        Code = code;
    }
}

/// <summary>Exception thrown when a network request fails</summary>
public class EnvoiceNetworkException : EnvoiceException
{
    public EnvoiceNetworkException(string message) : base(message) { }
    public EnvoiceNetworkException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>Exception thrown when quota is exceeded</summary>
public class EnvoiceQuotaExceededException : EnvoiceApiException
{
    public EnvoiceQuotaExceededException(string message) : base(message, 402, "quota_exceeded") { }
}
