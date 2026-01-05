import type {
  GenerateRequest,
  GenerateResponse,
  ErrorResponse,
  InvoiceResult,
} from './types';
import { InvoiceBuilder, InvoiceSuccess } from './invoice-builder';
import {
  EnvoiceApiError,
  EnvoiceNetworkError,
  EnvoiceQuotaExceededError,
} from './errors';

/**
 * Configuration options for the EnvoiceClient
 */
export interface EnvoiceClientOptions {
  /**
   * API base URL (default: https://api.envoice.dev)
   */
  apiUrl?: string;
  /**
   * Request timeout in milliseconds (default: 30000)
   */
  timeout?: number;
  /**
   * Custom fetch function (for testing or custom environments)
   */
  fetch?: typeof fetch;
}

/**
 * Main client for interacting with the envoice.dev API
 */
export class EnvoiceClient {
  private apiKey: string;
  private apiUrl: string;
  private timeout: number;
  private fetchFn: typeof fetch;

  /**
   * Create a new EnvoiceClient
   * @param apiKey Your API key (env_sandbox_* or env_live_*)
   * @param options Optional configuration
   */
  constructor(apiKey: string, options: EnvoiceClientOptions = {}) {
    if (!apiKey) {
      throw new Error('API key is required');
    }
    this.apiKey = apiKey;
    this.apiUrl = options.apiUrl || 'https://api.envoice.dev';
    this.timeout = options.timeout || 30000;
    this.fetchFn = options.fetch || fetch.bind(globalThis);
  }

  /**
   * Create a new invoice builder with fluent API
   */
  invoice(): InvoiceBuilder {
    return new InvoiceBuilder(this);
  }

  /**
   * Generate an invoice directly (without builder)
   */
  async generateInvoice(request: GenerateRequest): Promise<InvoiceResult> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const response = await this.fetchFn(`${this.apiUrl}/v1/generate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this.apiKey,
        },
        body: JSON.stringify(request),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (response.ok) {
        const data: GenerateResponse = await response.json();
        return {
          success: true,
          pdfBase64: data.pdf_base64,
          filename: data.filename,
          validation: data.validation,
          account: data.account,
        };
      }

      // Handle errors
      const errorData: ErrorResponse = await response.json().catch(() => ({
        error: 'unknown_error',
        message: `HTTP ${response.status}`,
      }));

      if (response.status === 402) {
        throw new EnvoiceQuotaExceededError(errorData.message || 'Quota exceeded');
      }

      if (response.status === 422 && errorData.details) {
        return {
          success: false,
          errors: errorData.details,
        };
      }

      throw EnvoiceApiError.fromResponse(errorData, response.status);
    } catch (error) {
      if (error instanceof EnvoiceApiError) {
        throw error;
      }

      if (error instanceof Error) {
        if (error.name === 'AbortError') {
          throw new EnvoiceNetworkError('Request timeout');
        }
        throw new EnvoiceNetworkError(error.message, error);
      }

      throw new EnvoiceNetworkError('Unknown error');
    }
  }

  /**
   * Validate an existing PDF for ZUGFeRD/Factur-X compliance
   */
  async validate(pdfBase64: string): Promise<{
    valid: boolean;
    profile?: string;
    version?: string;
    errors?: string[];
    warnings?: string[];
  }> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const response = await this.fetchFn(`${this.apiUrl}/v1/validate`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this.apiKey,
        },
        body: JSON.stringify({ pdf_base64: pdfBase64 }),
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData: ErrorResponse = await response.json().catch(() => ({
          error: 'unknown_error',
        }));
        throw EnvoiceApiError.fromResponse(errorData, response.status);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof EnvoiceApiError) {
        throw error;
      }

      if (error instanceof Error) {
        throw new EnvoiceNetworkError(error.message, error);
      }

      throw new EnvoiceNetworkError('Unknown error');
    }
  }

  /**
   * Get account information (quota, plan, etc.)
   */
  async getAccount(): Promise<{
    plan: string;
    remaining: number;
    used: number;
    limit: number;
  }> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const response = await this.fetchFn(`${this.apiUrl}/v1/account`, {
        method: 'GET',
        headers: {
          'X-API-Key': this.apiKey,
        },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData: ErrorResponse = await response.json().catch(() => ({
          error: 'unknown_error',
        }));
        throw EnvoiceApiError.fromResponse(errorData, response.status);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof EnvoiceApiError) {
        throw error;
      }

      if (error instanceof Error) {
        throw new EnvoiceNetworkError(error.message, error);
      }

      throw new EnvoiceNetworkError('Unknown error');
    }
  }
}
