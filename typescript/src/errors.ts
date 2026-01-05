import type { ValidationError, ErrorResponse } from './types';

/**
 * Base error class for all envoice SDK errors
 */
export class EnvoiceError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EnvoiceError';
  }
}

/**
 * Error thrown when the API returns a validation error
 */
export class EnvoiceValidationError extends EnvoiceError {
  public readonly errors: ValidationError[];
  public readonly statusCode: number;

  constructor(errors: ValidationError[], statusCode = 422) {
    const message = errors.map(e => `${e.path}: ${e.message}`).join('; ');
    super(`Validation failed: ${message}`);
    this.name = 'EnvoiceValidationError';
    this.errors = errors;
    this.statusCode = statusCode;
  }

  /**
   * Get a user-friendly error message
   */
  toUserMessage(): string {
    return this.errors
      .map(e => `- ${e.path}: ${e.message}`)
      .join('\n');
  }
}

/**
 * Error thrown when the API returns an HTTP error
 */
export class EnvoiceApiError extends EnvoiceError {
  public readonly statusCode: number;
  public readonly code?: string;

  constructor(message: string, statusCode: number, code?: string) {
    super(message);
    this.name = 'EnvoiceApiError';
    this.statusCode = statusCode;
    this.code = code;
  }

  static fromResponse(response: ErrorResponse, statusCode: number): EnvoiceApiError {
    if (response.details && response.details.length > 0) {
      return new EnvoiceValidationError(response.details, statusCode);
    }
    return new EnvoiceApiError(
      response.message || response.error || 'Unknown error',
      statusCode,
      response.error
    );
  }
}

/**
 * Error thrown when network request fails
 */
export class EnvoiceNetworkError extends EnvoiceError {
  public readonly cause?: Error;

  constructor(message: string, cause?: Error) {
    super(message);
    this.name = 'EnvoiceNetworkError';
    this.cause = cause;
  }
}

/**
 * Error thrown when quota is exceeded
 */
export class EnvoiceQuotaExceededError extends EnvoiceApiError {
  constructor(message: string) {
    super(message, 402, 'quota_exceeded');
    this.name = 'EnvoiceQuotaExceededError';
  }
}
