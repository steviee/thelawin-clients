namespace Thelawin;

/// <summary>Base exception for all Thelawin SDK errors</summary>
public class ThelawinException : Exception
{
    public ThelawinException(string message) : base(message) { }
    public ThelawinException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>Exception thrown when the API returns validation errors</summary>
public class ThelawinValidationException : ThelawinException
{
    public IReadOnlyList<ValidationError> Errors { get; }
    public int StatusCode { get; }

    public ThelawinValidationException(IReadOnlyList<ValidationError> errors, int statusCode = 422)
        : base($"Validation failed: {string.Join("; ", errors.Select(e => $"{e.Path}: {e.Message}"))}")
    {
        Errors = errors;
        StatusCode = statusCode;
    }

    public string ToUserMessage() => string.Join("\n", Errors.Select(e => $"- {e.Path}: {e.Message}"));
}

/// <summary>Exception thrown when the API returns an HTTP error</summary>
public class ThelawinApiException : ThelawinException
{
    public int StatusCode { get; }
    public string? Code { get; }

    public ThelawinApiException(string message, int statusCode, string? code = null) : base(message)
    {
        StatusCode = statusCode;
        Code = code;
    }
}

/// <summary>Exception thrown when a network request fails</summary>
public class ThelawinNetworkException : ThelawinException
{
    public ThelawinNetworkException(string message) : base(message) { }
    public ThelawinNetworkException(string message, Exception innerException) : base(message, innerException) { }
}

/// <summary>Exception thrown when quota is exceeded</summary>
public class ThelawinQuotaExceededException : ThelawinApiException
{
    public ThelawinQuotaExceededException(string message) : base(message, 402, "quota_exceeded") { }
}
