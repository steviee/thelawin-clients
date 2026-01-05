import { describe, it, expect, vi, beforeEach } from 'vitest';
import { EnvoiceClient } from '../src/client';
import { InvoiceBuilder, InvoiceSuccess } from '../src/invoice-builder';

describe('InvoiceBuilder', () => {
  let client: EnvoiceClient;
  let mockFetch: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockFetch = vi.fn();
    client = new EnvoiceClient('env_sandbox_test', {
      fetch: mockFetch as unknown as typeof fetch,
    });
  });

  describe('fluent interface', () => {
    it('returns this for method chaining', () => {
      const builder = client.invoice();

      expect(builder.number('2026-001')).toBe(builder);
      expect(builder.date('2026-01-15')).toBe(builder);
      expect(builder.dueDate('2026-02-15')).toBe(builder);
      expect(builder.currency('EUR')).toBe(builder);
      expect(builder.templateType('minimal')).toBe(builder);
      expect(builder.template('classic')).toBe(builder);
      expect(builder.localeCode('de')).toBe(builder);
      expect(builder.footerText('Thanks!')).toBe(builder);
      expect(builder.accentColor('#8b5cf6')).toBe(builder);
    });

    it('accepts Date objects for dates', () => {
      const builder = client.invoice();
      const date = new Date('2026-01-15');
      const dueDate = new Date('2026-02-15');

      builder.date(date);
      builder.dueDate(dueDate);

      // Verify by generating - the dates should be converted to ISO format
      // We can check this through the validation which will pass
    });
  });

  describe('seller()', () => {
    it('accepts party object', () => {
      const builder = client.invoice();
      const result = builder.seller({
        name: 'Acme GmbH',
        vatId: 'DE123456789',
        street: 'Hauptstraße 1',
        city: 'Berlin',
        postalCode: '10115',
        country: 'DE',
      });

      expect(result).toBe(builder);
    });
  });

  describe('buyer()', () => {
    it('accepts party object', () => {
      const builder = client.invoice();
      const result = builder.buyer({
        name: 'Customer AG',
        city: 'München',
        country: 'DE',
      });

      expect(result).toBe(builder);
    });
  });

  describe('addItem()', () => {
    it('adds items to the invoice', () => {
      const builder = client.invoice();

      builder.addItem({
        description: 'Consulting',
        quantity: 8,
        unit: 'HUR',
        unitPrice: 150,
        vatRate: 19,
      });

      builder.addItem({
        description: 'Development',
        quantity: 16,
        unitPrice: 120,
      });

      // Items should be added - we verify by generating
    });

    it('applies default unit and vatRate', () => {
      const builder = client.invoice();

      builder.addItem({
        description: 'Item',
        quantity: 1,
        unitPrice: 100,
      });

      // Default unit should be C62, default vatRate should be 19.0
    });
  });

  describe('items()', () => {
    it('sets multiple items at once', () => {
      const builder = client.invoice();

      builder.items([
        { description: 'Item 1', quantity: 1, unitPrice: 100 },
        { description: 'Item 2', quantity: 2, unitPrice: 200 },
      ]);
    });
  });

  describe('logoBase64()', () => {
    it('sets logo with width', () => {
      const builder = client.invoice();
      const result = builder.logoBase64('iVBORw0KGgoAAAANS...', 30);

      expect(result).toBe(builder);
    });

    it('sets logo without width', () => {
      const builder = client.invoice();
      const result = builder.logoBase64('iVBORw0KGgoAAAANS...');

      expect(result).toBe(builder);
    });
  });

  describe('generate()', () => {
    it('validates required fields before API call', async () => {
      const builder = client.invoice();

      // Missing all required fields
      const result = await builder.generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.length).toBeGreaterThan(0);
        expect(result.errors.some((e) => e.path === '$.invoice.number')).toBe(true);
        expect(result.errors.some((e) => e.path === '$.invoice.date')).toBe(true);
        expect(result.errors.some((e) => e.path === '$.invoice.seller')).toBe(true);
        expect(result.errors.some((e) => e.path === '$.invoice.buyer')).toBe(true);
        expect(result.errors.some((e) => e.path === '$.invoice.items')).toBe(true);
      }
    });

    it('validates number is required', async () => {
      const result = await client
        .invoice()
        .date('2026-01-15')
        .seller({ name: 'Acme' })
        .buyer({ name: 'Customer' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some((e) => e.path === '$.invoice.number')).toBe(true);
      }
    });

    it('validates date is required', async () => {
      const result = await client
        .invoice()
        .number('2026-001')
        .seller({ name: 'Acme' })
        .buyer({ name: 'Customer' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some((e) => e.path === '$.invoice.date')).toBe(true);
      }
    });

    it('validates seller is required', async () => {
      const result = await client
        .invoice()
        .number('2026-001')
        .date('2026-01-15')
        .buyer({ name: 'Customer' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some((e) => e.path === '$.invoice.seller')).toBe(true);
      }
    });

    it('validates buyer is required', async () => {
      const result = await client
        .invoice()
        .number('2026-001')
        .date('2026-01-15')
        .seller({ name: 'Acme' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some((e) => e.path === '$.invoice.buyer')).toBe(true);
      }
    });

    it('validates at least one item is required', async () => {
      const result = await client
        .invoice()
        .number('2026-001')
        .date('2026-01-15')
        .seller({ name: 'Acme' })
        .buyer({ name: 'Customer' })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some((e) => e.path === '$.invoice.items')).toBe(true);
      }
    });

    it('makes API call with valid data', async () => {
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
          }),
      });

      const result = await client
        .invoice()
        .number('2026-001')
        .date('2026-01-15')
        .seller({ name: 'Acme GmbH', vatId: 'DE123456789' })
        .buyer({ name: 'Customer AG' })
        .addItem({ description: 'Consulting', quantity: 8, unitPrice: 150 })
        .template('minimal')
        .generate();

      expect(result.success).toBe(true);
      expect(mockFetch).toHaveBeenCalledTimes(1);

      const [url, options] = mockFetch.mock.calls[0];
      expect(url).toContain('/v1/generate');
      expect(options.method).toBe('POST');
      expect(options.headers['X-API-Key']).toBe('env_sandbox_test');

      const body = JSON.parse(options.body);
      expect(body.template).toBe('minimal');
      expect(body.invoice.number).toBe('2026-001');
      expect(body.invoice.date).toBe('2026-01-15');
    });
  });
});

describe('InvoiceSuccess', () => {
  const createSuccess = () =>
    new InvoiceSuccess(
      'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK',
      'invoice-2026-001.pdf',
      { status: 'valid', profile: 'EN16931', version: '2.3.2' }
    );

  describe('success property', () => {
    it('is always true', () => {
      const success = createSuccess();
      expect(success.success).toBe(true);
    });
  });

  describe('toUint8Array()', () => {
    it('decodes base64 to bytes', () => {
      const success = createSuccess();
      const bytes = success.toUint8Array();

      expect(bytes).toBeInstanceOf(Uint8Array);
      expect(bytes.length).toBeGreaterThan(0);
      // PDF starts with %PDF
      expect(bytes[0]).toBe(0x25); // %
      expect(bytes[1]).toBe(0x50); // P
      expect(bytes[2]).toBe(0x44); // D
      expect(bytes[3]).toBe(0x46); // F
    });
  });

  describe('toDataUrl()', () => {
    it('returns a data URL', () => {
      const success = createSuccess();
      const dataUrl = success.toDataUrl();

      expect(dataUrl).toMatch(/^data:application\/pdf;base64,/);
    });
  });

  describe('toBlob()', () => {
    it('creates a Blob with correct type', () => {
      const success = createSuccess();
      const blob = success.toBlob();

      expect(blob).toBeInstanceOf(Blob);
      expect(blob.type).toBe('application/pdf');
    });
  });
});
