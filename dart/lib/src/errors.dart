import 'types.dart';

/// Base exception for all thelawin SDK errors
class ThelawinException implements Exception {
  final String message;
  ThelawinException(this.message);

  @override
  String toString() => message;
}

/// Exception thrown when the API returns validation errors
class ThelawinValidationException extends ThelawinException {
  final List<ValidationError> errors;
  final int statusCode;

  ThelawinValidationException(this.errors, [this.statusCode = 422])
      : super('Validation failed: ${errors.map((e) => '${e.path}: ${e.message}').join('; ')}');

  String toUserMessage() => errors.map((e) => '- ${e.path}: ${e.message}').join('\n');
}

/// Exception thrown when the API returns an HTTP error
class ThelawinApiException extends ThelawinException {
  final int statusCode;
  final String? code;

  ThelawinApiException(super.message, this.statusCode, [this.code]);
}

/// Exception thrown when a network request fails
class ThelawinNetworkException extends ThelawinException {
  final Object? cause;

  ThelawinNetworkException(super.message, [this.cause]);
}

/// Exception thrown when quota is exceeded
class ThelawinQuotaExceededException extends ThelawinApiException {
  ThelawinQuotaExceededException(String message) : super(message, 402, 'quota_exceeded');
}
