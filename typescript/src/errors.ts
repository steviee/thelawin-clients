import type { ValidationError, ErrorResponse } from './types';

export class ThelawinError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'ThelawinError';
  }
}

export class ThelawinValidationError extends ThelawinError {
  public readonly errors: ValidationError[];
  public readonly statusCode: number;

  constructor(errors: ValidationError[], statusCode = 422) {
    const message = errors.map(e => `${e.path}: ${e.message}`).join('; ');
    super(`Validation failed: ${message}`);
    this.name = 'ThelawinValidationError';
    this.errors = errors;
    this.statusCode = statusCode;
  }

  toUserMessage(): string {
    return this.errors
      .map(e => `- ${e.path}: ${e.message}`)
      .join('\n');
  }
}

export class ThelawinApiError extends ThelawinError {
  public readonly statusCode: number;
  public readonly code?: string;

  constructor(message: string, statusCode: number, code?: string) {
    super(message);
    this.name = 'ThelawinApiError';
    this.statusCode = statusCode;
    this.code = code;
  }

  static fromResponse(response: ErrorResponse, statusCode: number): ThelawinApiError {
    if (response.details && response.details.length > 0) {
      return new ThelawinValidationError(response.details, statusCode);
    }
    return new ThelawinApiError(
      response.message || response.error || 'Unknown error',
      statusCode,
      response.error
    );
  }
}

export class ThelawinNetworkError extends ThelawinError {
  public readonly cause?: Error;

  constructor(message: string, cause?: Error) {
    super(message);
    this.name = 'ThelawinNetworkError';
    this.cause = cause;
  }
}

export class ThelawinQuotaExceededError extends ThelawinApiError {
  constructor(message: string) {
    super(message, 402, 'quota_exceeded');
    this.name = 'ThelawinQuotaExceededError';
  }
}
