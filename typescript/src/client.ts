import type {
  GenerateRequest,
  GenerateResponse,
  ErrorResponse,
  InvoiceResult,
  DryRunResponse,
  RetrieveRequest,
  RetrieveResponse,
  AccountInfo,
} from './types';
import { InvoiceBuilder, InvoiceSuccess } from './invoice-builder';
import {
  ThelawinApiError,
  ThelawinNetworkError,
  ThelawinQuotaExceededError,
} from './errors';

export interface ThelawinClientOptions {
  apiUrl?: string;
  timeout?: number;
  fetch?: typeof fetch;
}

const DEFAULT_API_URL = 'https://api.thelawin.dev';
const DEFAULT_TIMEOUT = 30000;

export class ThelawinClient {
  private apiKey: string;
  private apiUrl: string;
  private timeout: number;
  private fetchFn: typeof fetch;

  constructor(apiKey: string, options: ThelawinClientOptions = {}) {
    if (!apiKey) {
      throw new Error('API key is required');
    }
    this.apiKey = apiKey;
    this.apiUrl = options.apiUrl || DEFAULT_API_URL;
    this.timeout = options.timeout || DEFAULT_TIMEOUT;
    this.fetchFn = options.fetch || fetch.bind(globalThis);
  }

  invoice(): InvoiceBuilder {
    return new InvoiceBuilder(this);
  }

  async generateInvoice(request: GenerateRequest): Promise<InvoiceResult> {
    try {
      const response = await this.request('POST', '/v1/generate', request);

      if (response.ok) {
        const data: GenerateResponse = await response.json();
        return {
          success: true,
          pdfBase64: data.pdf_base64,
          filename: data.filename,
          format: data.format,
          account: data.account,
        };
      }

      const errorData: ErrorResponse = await response.json().catch(() => ({
        error: 'unknown_error',
        message: `HTTP ${response.status}`,
      }));

      if (response.status === 402) {
        throw new ThelawinQuotaExceededError(errorData.message || 'Quota exceeded');
      }

      if (response.status === 422 && errorData.details) {
        return {
          success: false,
          errors: errorData.details,
        };
      }

      throw ThelawinApiError.fromResponse(errorData, response.status);
    } catch (error) {
      if (error instanceof ThelawinApiError) throw error;
      if (error instanceof Error) {
        if (error.name === 'AbortError') throw new ThelawinNetworkError('Request timeout');
        throw new ThelawinNetworkError(error.message, error);
      }
      throw new ThelawinNetworkError('Unknown error');
    }
  }

  async validate(request: GenerateRequest): Promise<DryRunResponse> {
    try {
      const response = await this.request('POST', '/v1/validate', request);

      if (!response.ok) {
        const errorData: ErrorResponse = await response.json().catch(() => ({
          error: 'unknown_error',
        }));
        throw ThelawinApiError.fromResponse(errorData, response.status);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof ThelawinApiError) throw error;
      if (error instanceof Error) throw new ThelawinNetworkError(error.message, error);
      throw new ThelawinNetworkError('Unknown error');
    }
  }

  async retrieve(dataBase64: string, options?: { contentType?: string; includeSourceXml?: boolean }): Promise<RetrieveResponse> {
    const body: RetrieveRequest = {
      data_base64: dataBase64,
      content_type: options?.contentType,
      include_source_xml: options?.includeSourceXml,
    };

    try {
      const response = await this.request('POST', '/v1/retrieve', body);

      if (!response.ok) {
        const errorData: ErrorResponse = await response.json().catch(() => ({
          error: 'unknown_error',
        }));

        if (response.status === 402) {
          throw new ThelawinQuotaExceededError(errorData.message || 'Quota exceeded');
        }

        throw ThelawinApiError.fromResponse(errorData, response.status);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof ThelawinApiError) throw error;
      if (error instanceof Error) throw new ThelawinNetworkError(error.message, error);
      throw new ThelawinNetworkError('Unknown error');
    }
  }

  async getAccount(): Promise<AccountInfo> {
    try {
      const controller = new AbortController();
      const timeoutId = setTimeout(() => controller.abort(), this.timeout);

      const response = await this.fetchFn(`${this.apiUrl}/v1/account`, {
        method: 'GET',
        headers: { 'X-API-Key': this.apiKey },
        signal: controller.signal,
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorData: ErrorResponse = await response.json().catch(() => ({
          error: 'unknown_error',
        }));
        throw ThelawinApiError.fromResponse(errorData, response.status);
      }

      return await response.json();
    } catch (error) {
      if (error instanceof ThelawinApiError) throw error;
      if (error instanceof Error) throw new ThelawinNetworkError(error.message, error);
      throw new ThelawinNetworkError('Unknown error');
    }
  }

  private async request(method: string, path: string, body?: unknown): Promise<Response> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      return await this.fetchFn(`${this.apiUrl}${path}`, {
        method,
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': this.apiKey,
        },
        body: body ? JSON.stringify(body) : undefined,
        signal: controller.signal,
      });
    } finally {
      clearTimeout(timeoutId);
    }
  }
}
