import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { EnvoiceClient } from '../src/client';
import {
  EnvoiceApiError,
  EnvoiceNetworkError,
  EnvoiceQuotaExceededError,
} from '../src/errors';

describe('EnvoiceClient', () => {
  describe('constructor', () => {
    it('requires an API key', () => {
      expect(() => new EnvoiceClient('')).toThrow('API key is required');
    });

    it('creates a client with valid API key', () => {
      const client = new EnvoiceClient('env_sandbox_test');
      expect(client).toBeInstanceOf(EnvoiceClient);
    });

    it('uses default options', () => {
      const client = new EnvoiceClient('env_sandbox_test');
      // Internal properties - we test behavior instead
      expect(client.invoice()).toBeDefined();
    });

    it('accepts custom options', () => {
      const client = new EnvoiceClient('env_sandbox_test', {
        apiUrl: 'https://custom.api.url',
        timeout: 60000,
      });
      expect(client).toBeInstanceOf(EnvoiceClient);
    });
  });

  describe('invoice()', () => {
    it('returns an InvoiceBuilder', () => {
      const client = new EnvoiceClient('env_sandbox_test');
      const builder = client.invoice();
      expect(builder).toBeDefined();
      expect(typeof builder.number).toBe('function');
      expect(typeof builder.date).toBe('function');
      expect(typeof builder.seller).toBe('function');
      expect(typeof builder.buyer).toBe('function');
      expect(typeof builder.addItem).toBe('function');
      expect(typeof builder.generate).toBe('function');
    });
  });

  describe('generateInvoice()', () => {
    let client: EnvoiceClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new EnvoiceClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    afterEach(() => {
      vi.clearAllMocks();
    });

    it('returns success result on 200', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () =>
          Promise.resolve({
            pdf_base64: 'JVBERi0xLjQK...',
            filename: 'invoice-2026-001.pdf',
            validation: {
              status: 'valid',
              profile: 'EN16931',
              version: '2.3.2',
            },
            account: {
              remaining: 499,
              plan: 'starter',
            },
          }),
      });

      const result = await client.generateInvoice({
        template: 'minimal',
        invoice: {
          number: '2026-001',
          date: '2026-01-15',
          seller: { name: 'Acme GmbH' },
          buyer: { name: 'Customer AG' },
          items: [{ description: 'Consulting', quantity: 8, unitPrice: 150 }],
        },
      });

      expect(result.success).toBe(true);
      if (result.success) {
        expect(result.pdfBase64).toBe('JVBERi0xLjQK...');
        expect(result.filename).toBe('invoice-2026-001.pdf');
        expect(result.validation.profile).toBe('EN16931');
        expect(result.account?.remaining).toBe(499);
      }
    });

    it('returns validation errors on 422', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 422,
        json: () =>
          Promise.resolve({
            error: 'validation_error',
            message: 'Validation failed',
            details: [
              {
                path: '$.invoice.seller.vatId',
                code: 'INVALID_FORMAT',
                message: 'Invalid VAT ID format',
              },
            ],
          }),
      });

      const result = await client.generateInvoice({
        template: 'minimal',
        invoice: {
          number: '2026-001',
          date: '2026-01-15',
          seller: { name: 'Acme GmbH', vatId: 'INVALID' },
          buyer: { name: 'Customer AG' },
          items: [{ description: 'Consulting', quantity: 8, unitPrice: 150 }],
        },
      });

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors).toHaveLength(1);
        expect(result.errors[0].path).toBe('$.invoice.seller.vatId');
        expect(result.errors[0].code).toBe('INVALID_FORMAT');
      }
    });

    it('throws EnvoiceQuotaExceededError on 402', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 402,
        json: () =>
          Promise.resolve({
            error: 'quota_exceeded',
            message: 'Monthly quota exceeded',
          }),
      });

      await expect(
        client.generateInvoice({
          template: 'minimal',
          invoice: {
            number: '2026-001',
            date: '2026-01-15',
            seller: { name: 'Acme GmbH' },
            buyer: { name: 'Customer AG' },
            items: [{ description: 'Item', quantity: 1, unitPrice: 100 }],
          },
        })
      ).rejects.toThrow(EnvoiceQuotaExceededError);
    });

    it('throws EnvoiceApiError on other HTTP errors', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: false,
        status: 500,
        json: () =>
          Promise.resolve({
            error: 'internal_error',
            message: 'Internal server error',
          }),
      });

      await expect(
        client.generateInvoice({
          template: 'minimal',
          invoice: {
            number: '2026-001',
            date: '2026-01-15',
            seller: { name: 'Acme GmbH' },
            buyer: { name: 'Customer AG' },
            items: [{ description: 'Item', quantity: 1, unitPrice: 100 }],
          },
        })
      ).rejects.toThrow(EnvoiceApiError);
    });

    it('throws EnvoiceNetworkError on timeout', async () => {
      mockFetch.mockImplementationOnce(
        () =>
          new Promise((_, reject) => {
            const error = new Error('Aborted');
            error.name = 'AbortError';
            reject(error);
          })
      );

      await expect(
        client.generateInvoice({
          template: 'minimal',
          invoice: {
            number: '2026-001',
            date: '2026-01-15',
            seller: { name: 'Acme GmbH' },
            buyer: { name: 'Customer AG' },
            items: [{ description: 'Item', quantity: 1, unitPrice: 100 }],
          },
        })
      ).rejects.toThrow(EnvoiceNetworkError);
    });

    it('throws EnvoiceNetworkError on network failure', async () => {
      mockFetch.mockRejectedValueOnce(new Error('Network error'));

      await expect(
        client.generateInvoice({
          template: 'minimal',
          invoice: {
            number: '2026-001',
            date: '2026-01-15',
            seller: { name: 'Acme GmbH' },
            buyer: { name: 'Customer AG' },
            items: [{ description: 'Item', quantity: 1, unitPrice: 100 }],
          },
        })
      ).rejects.toThrow(EnvoiceNetworkError);
    });
  });

  describe('validate()', () => {
    let client: EnvoiceClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new EnvoiceClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    it('returns validation result on success', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () =>
          Promise.resolve({
            valid: true,
            profile: 'EN16931',
            version: '2.3.2',
            errors: [],
            warnings: [],
          }),
      });

      const result = await client.validate('JVBERi0xLjQK...');

      expect(result.valid).toBe(true);
      expect(result.profile).toBe('EN16931');
      expect(result.version).toBe('2.3.2');
    });
  });

  describe('getAccount()', () => {
    let client: EnvoiceClient;
    let mockFetch: ReturnType<typeof vi.fn>;

    beforeEach(() => {
      mockFetch = vi.fn();
      client = new EnvoiceClient('env_sandbox_test', {
        fetch: mockFetch as unknown as typeof fetch,
      });
    });

    it('returns account info on success', async () => {
      mockFetch.mockResolvedValueOnce({
        ok: true,
        json: () =>
          Promise.resolve({
            plan: 'starter',
            remaining: 450,
            used: 50,
            limit: 500,
          }),
      });

      const account = await client.getAccount();

      expect(account.plan).toBe('starter');
      expect(account.remaining).toBe(450);
      expect(account.used).toBe(50);
      expect(account.limit).toBe(500);
    });
  });
});
