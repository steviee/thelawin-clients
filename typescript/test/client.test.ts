import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { ThelawinClient } from '../src/client';
import {
  ThelawinApiError,
  ThelawinNetworkError,
  ThelawinQuotaExceededError,
  ThelawinValidationError,
} from '../src/errors';
import type { GenerateRequest } from '../src/types';

const MINIMAL_REQUEST: GenerateRequest = {
  template: 'minimal',
  invoice: {
    number: '2026-001',
    date: '2026-01-15',
    seller: { name: 'Acme GmbH' },
    buyer: { name: 'Customer AG' },
    items: [{ description: 'Consulting', quantity: 8, unitPrice: 150 }],
  },
};

function mockResponse(status: number, body: unknown, ok?: boolean) {
  return {
    ok: ok ?? (status >= 200 && status < 300),
    status,
    json: () => Promise.resolve(body),
  };
}

describe('ThelawinClient', () => {
  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------
  describe('constructor', () => {
    it('requires an API key', () => {
      expect(() => new ThelawinClient('')).toThrow('API key is required');
    });

    it('creates a client with valid API key', () => {
      const client = new ThelawinClient('env_sandbox_test');
      expect(client).toBeInstanceOf(ThelawinClient);
    });

    it('accepts custom apiUrl', () => {
      const client = new ThelawinClient('env_sandbox_test', {
        apiUrl: 'https://api.preview.thelawin.dev',
      });
      expect(client).toBeInstanceOf(ThelawinClient);
    });

    it('accepts custom timeout', () => {
      const client = new ThelawinClient('env_sandbox_test', { timeout: 60000 });
      expect(client).toBeInstanceOf(ThelawinClient);
    });

    it('accepts custom fetch function', () => {
      const mockFetch = vi.fn();
      const client = new ThelawinClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
      expect(client).toBeInstanceOf(ThelawinClient);
    });
  });

  // ---------------------------------------------------------------------------
  // invoice()
  // ---------------------------------------------------------------------------
  describe('invoice()', () => {
    it('returns an InvoiceBuilder', () => {
      const client = new ThelawinClient('env_sandbox_test');
      const builder = client.invoice();
      expect(builder).toBeDefined();
      expect(typeof builder.number).toBe('function');
      expect(typeof builder.date).toBe('function');
      expect(typeof builder.seller).toBe('function');
      expect(typeof builder.buyer).toBe('function');
      expect(typeof builder.addItem).toBe('function');
      expect(typeof builder.format).toBe('function');
      expect(typeof builder.profile).toBe('function');
      expect(typeof builder.template).toBe('function');
      expect(typeof builder.generate).toBe('function');
    });
  });

  // ---------------------------------------------------------------------------
  // generateInvoice()
  // ---------------------------------------------------------------------------
  describe('generateInvoice()', () => {
    let client: ThelawinClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new ThelawinClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    afterEach(() => vi.clearAllMocks());

    it('returns success result on 200', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'JVBERi0xLjQK...',
        filename: 'invoice-2026-001.pdf',
        format: { format_used: 'zugferd', profile: 'EN16931', version: '2.3' },
        account: { remaining: 499, plan: 'starter' },
      }));

      const result = await client.generateInvoice(MINIMAL_REQUEST);

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.pdfBase64).toBe('JVBERi0xLjQK...');
        expect(result.filename).toBe('invoice-2026-001.pdf');
        expect(result.format.format_used).toBe('zugferd');
        expect(result.format.profile).toBe('EN16931');
        expect(result.account?.remaining).toBe(499);
      }
    });

    it('sends correct headers and body', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'abc', filename: 'test.pdf',
        format: { format_used: 'zugferd' },
      }));

      await client.generateInvoice(MINIMAL_REQUEST);

      const [url, options] = mockFetch.mock.calls[0];
      expect(url).toContain('/v1/generate');
      expect(options.method).toBe('POST');
      expect(options.headers['Content-Type']).toBe('application/json');
      expect(options.headers['X-API-Key']).toBe('env_sandbox_test');
      const body = JSON.parse(options.body);
      expect(body.invoice.number).toBe('2026-001');
    });

    it('returns validation errors on 422 with details', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(422, {
        error: 'validation_failed',
        message: 'Validation failed',
        details: [
          { path: 'invoice.seller.vat_id', code: 'REQUIRED', message: 'VAT ID required for EN16931' },
        ],
      }, false));

      const result = await client.generateInvoice(MINIMAL_REQUEST);

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors).toHaveLength(1);
        expect(result.errors[0].path).toBe('invoice.seller.vat_id');
      }
    });

    it('throws ThelawinQuotaExceededError on 402', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(402, {
        error: 'quota_exceeded',
        message: 'Monthly quota exceeded',
      }, false));

      await expect(client.generateInvoice(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinQuotaExceededError);
    });

    it('throws ThelawinApiError on 401', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(401, {
        error: 'unauthorized',
        message: 'Invalid API key',
      }, false));

      await expect(client.generateInvoice(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinApiError);
    });

    it('throws ThelawinApiError on 500', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(500, {
        error: 'internal_error',
        message: 'Internal server error',
      }, false));

      await expect(client.generateInvoice(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinApiError);
    });

    it('throws ThelawinNetworkError on timeout (AbortError)', async () => {
      mockFetch.mockImplementationOnce(() => {
        const error = new Error('Aborted');
        error.name = 'AbortError';
        return Promise.reject(error);
      });

      await expect(client.generateInvoice(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinNetworkError);
    });

    it('throws ThelawinNetworkError on network failure', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      await expect(client.generateInvoice(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinNetworkError);
    });

    it('handles malformed JSON response gracefully', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: () => Promise.reject(new Error('Invalid JSON')),
      });

      await expect(client.generateInvoice(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinApiError);
    });
  });

  // ---------------------------------------------------------------------------
  // validate()
  // ---------------------------------------------------------------------------
  describe('validate()', () => {
    let client: ThelawinClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new ThelawinClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    afterEach(() => vi.clearAllMocks());

    it('returns valid DryRunResponse', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: true,
        format: { format_used: 'zugferd', profile: 'EN16931', version: '2.3' },
        errors: [],
      }));

      const result = await client.validate(MINIMAL_REQUEST);

      expect(result.valid).toBe(true);
      expect(result.format.format_used).toBe('zugferd');
      expect(result.errors).toEqual([]);
    });

    it('returns invalid DryRunResponse with errors', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: false,
        format: { format_used: 'zugferd', profile: 'EN16931' },
        errors: ['invoice.seller.vat_id: VAT ID required'],
      }));

      const result = await client.validate(MINIMAL_REQUEST);

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(1);
    });

    it('returns format detection info', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: true,
        format: {
          format_used: 'xrechnung',
          profile: 'EN16931',
          version: '3.0.2',
          format_reason: 'leitweg_id detected',
          warnings: [{ code: 'XRECHNUNG_B2G', message: 'B2G format', legal_basis: 'ERechV', severity: 'info' }],
        },
        errors: [],
      }));

      const result = await client.validate({
        ...MINIMAL_REQUEST,
        format: 'xrechnung',
        invoice: { ...MINIMAL_REQUEST.invoice, leitwegId: '04011000-12345-67' },
      });

      expect(result.format.format_used).toBe('xrechnung');
      expect(result.format.format_reason).toBe('leitweg_id detected');
    });

    it('throws ThelawinApiError on HTTP error', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(500, {
        error: 'internal_error', message: 'Server error',
      }, false));

      await expect(client.validate(MINIMAL_REQUEST))
        .rejects.toThrow(ThelawinApiError);
    });
  });

  // ---------------------------------------------------------------------------
  // retrieve()
  // ---------------------------------------------------------------------------
  describe('retrieve()', () => {
    let client: ThelawinClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new ThelawinClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    afterEach(() => vi.clearAllMocks());

    it('extracts invoice data from PDF', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: true,
        format: { detected_format: 'zugferd', profile: 'EN16931', version: '2.3', xml_type: 'CII', has_pdf: true },
        invoice: {
          number: 'RE-2026-001',
          date: '2026-01-15',
          seller: { name: 'Acme GmbH' },
          buyer: { name: 'Customer AG' },
          items: [{ description: 'Consulting', quantity: 8, unitPrice: 150 }],
        },
        transaction_id: 'tx_abc123',
        errors: [],
        warnings: [],
      }));

      const result = await client.retrieve('JVBERi0xLjQK...');

      expect(result.valid).toBe(true);
      expect(result.format.detected_format).toBe('zugferd');
      expect(result.format.has_pdf).toBe(true);
      expect(result.invoice?.number).toBe('RE-2026-001');
      expect(result.transaction_id).toBe('tx_abc123');
    });

    it('extracts invoice data from XML', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: true,
        format: { detected_format: 'ubl', xml_type: 'UBL', has_pdf: false },
        invoice: { number: 'UBL-001', date: '2026-01-15', seller: { name: 'Test' }, buyer: { name: 'Buyer' }, items: [] },
        transaction_id: 'tx_def456',
        errors: [],
        warnings: [],
      }));

      const result = await client.retrieve('PHhtbD4...', { contentType: 'application/xml' });

      expect(result.valid).toBe(true);
      expect(result.format.detected_format).toBe('ubl');
      expect(result.format.has_pdf).toBe(false);
    });

    it('includes source XML when requested', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: true,
        format: { detected_format: 'zugferd', has_pdf: true },
        invoice: { number: 'RE-001', date: '2026-01-01', seller: { name: 'S' }, buyer: { name: 'B' }, items: [] },
        source_xml_base64: 'PHhtbCB2ZXJzaW9uPQ==',
        transaction_id: 'tx_ghi789',
        errors: [],
        warnings: [],
      }));

      const result = await client.retrieve('JVBERi0...', { includeSourceXml: true });

      expect(result.source_xml_base64).toBe('PHhtbCB2ZXJzaW9uPQ==');
    });

    it('sends correct request body', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: true,
        format: { detected_format: 'zugferd' },
        invoice: null,
        transaction_id: 'tx_test',
        errors: [],
        warnings: [],
      }));

      await client.retrieve('base64data', { contentType: 'application/pdf', includeSourceXml: true });

      const [url, options] = mockFetch.mock.calls[0];
      expect(url).toContain('/v1/retrieve');
      expect(options.method).toBe('POST');
      const body = JSON.parse(options.body);
      expect(body.data_base64).toBe('base64data');
      expect(body.content_type).toBe('application/pdf');
      expect(body.include_source_xml).toBe(true);
    });

    it('returns errors for invalid files', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        valid: false,
        format: { detected_format: 'unknown' },
        invoice: null,
        transaction_id: 'tx_err',
        errors: [{ code: 'INVALID_FILE', message: 'No e-invoice data found', severity: 'error' }],
        warnings: [],
      }));

      const result = await client.retrieve('notapdf');

      expect(result.valid).toBe(false);
      expect(result.errors).toHaveLength(1);
      expect(result.errors[0].code).toBe('INVALID_FILE');
    });

    it('throws ThelawinQuotaExceededError on 402', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(402, {
        error: 'quota_exceeded', message: 'Quota exceeded',
      }, false));

      await expect(client.retrieve('JVBERi0...')).rejects.toThrow(ThelawinQuotaExceededError);
    });

    it('throws ThelawinApiError on 401', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(401, {
        error: 'api_key_required', message: 'API key required',
      }, false));

      await expect(client.retrieve('JVBERi0...')).rejects.toThrow(ThelawinApiError);
    });
  });

  // ---------------------------------------------------------------------------
  // getAccount()
  // ---------------------------------------------------------------------------
  describe('getAccount()', () => {
    let client: ThelawinClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new ThelawinClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    afterEach(() => vi.clearAllMocks());

    it('returns account info', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        remaining: 450,
        plan: 'starter',
        overage_count: 0,
        overage_allowed: 75,
      }));

      const account = await client.getAccount();

      expect(account.plan).toBe('starter');
      expect(account.remaining).toBe(450);
      expect(account.overage_count).toBe(0);
      expect(account.overage_allowed).toBe(75);
    });

    it('returns sandbox account info', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        remaining: 2147483647,
        plan: 'sandbox',
      }));

      const account = await client.getAccount();

      expect(account.plan).toBe('sandbox');
      expect(account.remaining).toBe(2147483647);
    });

    it('includes warning when quota is low', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        remaining: 10,
        plan: 'starter',
        warning: 'Quota running low',
      }));

      const account = await client.getAccount();

      expect(account.warning).toBe('Quota running low');
    });

    it('throws ThelawinApiError on 401', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(401, {
        error: 'unauthorized', message: 'Invalid API key',
      }, false));

      await expect(client.getAccount()).rejects.toThrow(ThelawinApiError);
    });
  });
});
