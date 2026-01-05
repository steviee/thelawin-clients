import 'types.dart';

/// Base exception for all envoice SDK errors
class EnvoiceException implements Exception {
  final String message;
  EnvoiceException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when the API returns validation errors
class EnvoiceValidationException extends EnvoiceException {
  final List<ValidationError> errors;
  final int statusCode;

  EnvoiceValidationException(this.errors, [this.statusCode = 422])
      : super('Validation failed: ${errors.map((e) => '${e.path}: ${e.message}').join('; ')}');

  String toUserMessage() => errors.map((e) => '- ${e.path}: ${e.message}').join('\n');
}

/// Exception thrown when the API returns an HTTP error
class EnvoiceApiException extends EnvoiceException {
  final int statusCode;
  final String? code;

  EnvoiceApiException(super.message, this.statusCode, [this.code]);
}

/// Exception thrown when a network request fails
class EnvoiceNetworkException extends EnvoiceException {
  final Object? cause;

  EnvoiceNetworkException(super.message, [this.cause]);
}

/// Exception thrown when quota is exceeded
class EnvoiceQuotaExceededException extends EnvoiceApiException {
  EnvoiceQuotaExceededException(String message) : super(message, 402, 'quota_exceeded');
}
