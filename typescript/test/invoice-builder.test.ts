import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ThelawinClient } from '../src/client';
import { InvoiceBuilder, InvoiceSuccess } from '../src/invoice-builder';

function mockResponse(status: number, body: unknown) {
  return {
    ok: status >= 200 && status < 300,
    status,
    json: () => Promise.resolve(body),
  };
}

describe('InvoiceBuilder', () => {
  let client: ThelawinClient;
  let mockFetch: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    mockFetch = vi.fn();
    client = new ThelawinClient('env_sandbox_test', {
      fetch: mockFetch as unknown as typeof fetch,
    });
  });

  // ---------------------------------------------------------------------------
  // Fluent interface
  // ---------------------------------------------------------------------------
  describe('fluent interface', () => {
    it('returns this for all chain methods', () => {
      const builder = client.invoice();

      expect(builder.number('2026-001')).toBe(builder);
      expect(builder.date('2026-01-15')).toBe(builder);
      expect(builder.dueDate('2026-02-15')).toBe(builder);
      expect(builder.currency('EUR')).toBe(builder);
      expect(builder.notes('Thank you')).toBe(builder);
      expect(builder.format('zugferd')).toBe(builder);
      expect(builder.profile('en16931')).toBe(builder);
      expect(builder.template('minimal')).toBe(builder);
      expect(builder.locale('de')).toBe(builder);
      expect(builder.leitwegId('04011000-12345-67')).toBe(builder);
      expect(builder.buyerReference('PO-123')).toBe(builder);
      expect(builder.tipoDocumento('TD01')).toBe(builder);
      expect(builder.footerText('Footer')).toBe(builder);
      expect(builder.accentColor('#8b5cf6')).toBe(builder);
      expect(builder.logoBase64('abc')).toBe(builder);
    });

    it('accepts Date objects for dates', () => {
      const builder = client.invoice();
      expect(builder.date(new Date('2026-01-15'))).toBe(builder);
      expect(builder.dueDate(new Date('2026-02-15'))).toBe(builder);
    });
  });

  // ---------------------------------------------------------------------------
  // seller() / buyer()
  // ---------------------------------------------------------------------------
  describe('seller()', () => {
    it('accepts full party object', () => {
      const builder = client.invoice();
      const result = builder.seller({
        name: 'Acme GmbH',
        vatId: 'DE123456789',
        street: 'Hauptstraße 1',
        city: 'Berlin',
        postalCode: '10115',
        country: 'DE',
        email: 'info@acme.de',
        phone: '+49 30 12345',
      });
      expect(result).toBe(builder);
    });

    it('accepts party with Peppol fields', () => {
      const builder = client.invoice();
      expect(builder.seller({ name: 'EU Ltd', peppolId: '0088:1234567890123' })).toBe(builder);
    });

    it('accepts party with FatturaPA fields', () => {
      const builder = client.invoice();
      expect(builder.buyer({
        name: 'Italian SPA',
        codiceFiscale: '12345678901',
        codiceDestinatario: 'ABCDEFG',
        pec: 'test@pec.it',
      })).toBe(builder);
    });
  });

  // ---------------------------------------------------------------------------
  // addItem() / items()
  // ---------------------------------------------------------------------------
  describe('addItem()', () => {
    it('adds single items', () => {
      const builder = client.invoice();
      builder.addItem({ description: 'Consulting', quantity: 8, unit: 'HUR', unitPrice: 150, vatRate: 19 });
      builder.addItem({ description: 'Development', quantity: 16, unitPrice: 120 });
    });

    it('applies default unit C62 and vatRate 19', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'abc', filename: 'test.pdf', format: { format_used: 'zugferd' },
      }));

      await client.invoice()
        .number('001').date('2026-01-15')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      const body = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(body.invoice.items[0].unit).toBe('C62');
      expect(body.invoice.items[0].vatRate).toBe(19);
    });

    it('accepts FatturaPA natura field', () => {
      const builder = client.invoice();
      builder.addItem({ description: 'Service', quantity: 1, unitPrice: 100, vatRate: 0, natura: 'N4' });
    });
  });

  describe('items()', () => {
    it('sets multiple items at once', () => {
      const builder = client.invoice();
      builder.items([
        { description: 'Item 1', quantity: 1, unitPrice: 100 },
        { description: 'Item 2', quantity: 2, unitPrice: 200 },
        { description: 'Item 3', quantity: 3, unitPrice: 300 },
      ]);
    });
  });

  // ---------------------------------------------------------------------------
  // Format / Profile / Template
  // ---------------------------------------------------------------------------
  describe('format options', () => {
    it('sends format in request', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'abc', filename: 'test.pdf', format: { format_used: 'xrechnung' },
      }));

      await client.invoice()
        .number('XR-001').date('2026-01-15')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .format('xrechnung')
        .leitwegId('04011000-12345-67')
        .generate();

      const body = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(body.format).toBe('xrechnung');
      expect(body.invoice.leitwegId).toBe('04011000-12345-67');
    });

    it('sends profile in request', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'abc', filename: 'test.pdf', format: { format_used: 'zugferd' },
      }));

      await client.invoice()
        .number('001').date('2026-01-15')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .profile('extended')
        .generate();

      const body = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(body.profile).toBe('extended');
    });

    it('sends all template options', async () => {
      for (const tmpl of ['minimal', 'classic', 'compact'] as const) {
        mockFetch.mockResolvedValueOnce(mockResponse(200, {
          pdf_base64: 'abc', filename: 'test.pdf', format: { format_used: 'zugferd' },
        }));

        await client.invoice()
          .number('001').date('2026-01-15')
          .seller({ name: 'S' }).buyer({ name: 'B' })
          .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
          .template(tmpl)
          .generate();

        const body = JSON.parse(mockFetch.mock.calls[mockFetch.mock.calls.length - 1][1].body);
        expect(body.template).toBe(tmpl);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // logoBase64()
  // ---------------------------------------------------------------------------
  describe('logoBase64()', () => {
    it('sets logo with width', () => {
      const builder = client.invoice();
      expect(builder.logoBase64('iVBORw0KGgoAAAANS...', 30)).toBe(builder);
    });

    it('sends customization in request', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'abc', filename: 'test.pdf', format: { format_used: 'zugferd' },
      }));

      await client.invoice()
        .number('001').date('2026-01-15')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .logoBase64('logodata', 25)
        .footerText('Custom footer')
        .accentColor('#ff0000')
        .generate();

      const body = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(body.customization.logoBase64).toBe('logodata');
      expect(body.customization.logoWidthMm).toBe(25);
      expect(body.customization.footerText).toBe('Custom footer');
      expect(body.customization.accentColor).toBe('#ff0000');
    });
  });

  // ---------------------------------------------------------------------------
  // generate() — validation
  // ---------------------------------------------------------------------------
  describe('generate() validation', () => {
    it('rejects missing number', async () => {
      const result = await client.invoice()
        .date('2026-01-15')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some(e => e.path === '$.invoice.number')).toBe(true);
      }
    });

    it('rejects missing date', async () => {
      const result = await client.invoice()
        .number('001')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some(e => e.path === '$.invoice.date')).toBe(true);
      }
    });

    it('rejects missing seller', async () => {
      const result = await client.invoice()
        .number('001').date('2026-01-15')
        .buyer({ name: 'B' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some(e => e.path === '$.invoice.seller')).toBe(true);
      }
    });

    it('rejects missing buyer', async () => {
      const result = await client.invoice()
        .number('001').date('2026-01-15')
        .seller({ name: 'S' })
        .addItem({ description: 'Item', quantity: 1, unitPrice: 100 })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some(e => e.path === '$.invoice.buyer')).toBe(true);
      }
    });

    it('rejects missing items', async () => {
      const result = await client.invoice()
        .number('001').date('2026-01-15')
        .seller({ name: 'S' }).buyer({ name: 'B' })
        .generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors.some(e => e.path === '$.invoice.items')).toBe(true);
      }
    });

    it('rejects empty builder (first missing field)', async () => {
      const result = await client.invoice().generate();

      expect(result.success).toBe(false);
      if (!result.success) {
        expect(result.errors).toHaveLength(1);
        expect(result.errors[0].path).toBe('$.invoice.number');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // generate() — success
  // ---------------------------------------------------------------------------
  describe('generate() API call', () => {
    it('makes API call with complete invoice', async () => {
      mockFetch.mockResolvedValueOnce(mockResponse(200, {
        pdf_base64: 'JVBERi0xLjQK...',
        filename: 'invoice-2026-001.pdf',
        format: { format_used: 'zugferd', profile: 'EN16931', version: '2.3' },
      }));

      const result = await client.invoice()
        .number('2026-001')
        .date('2026-01-15')
        .dueDate('2026-02-15')
        .seller({ name: 'Acme GmbH', vatId: 'DE123456789', city: 'Berlin', country: 'DE' })
        .buyer({ name: 'Customer AG', city: 'München', country: 'DE' })
        .addItem({ description: 'Consulting', quantity: 8, unit: 'HUR', unitPrice: 150, vatRate: 19 })
        .payment({ iban: 'DE89370400440532013000', bic: 'COBADEFFXXX', terms: 'Net 30' })
        .currency('EUR')
        .notes('Thank you for your business')
        .format('zugferd')
        .profile('en16931')
        .template('minimal')
        .locale('de')
        .generate();

      expect(result.success).toBe(true);
      expect(mockFetch).toHaveBeenCalledOnce();

      const body = JSON.parse(mockFetch.mock.calls[0][1].body);
      expect(body.format).toBe('zugferd');
      expect(body.profile).toBe('en16931');
      expect(body.template).toBe('minimal');
      expect(body.locale).toBe('de');
      expect(body.invoice.number).toBe('2026-001');
      expect(body.invoice.payment.iban).toBe('DE89370400440532013000');
      expect(body.invoice.notes).toBe('Thank you for your business');
    });
  });
});

// ---------------------------------------------------------------------------
// InvoiceSuccess
// ---------------------------------------------------------------------------
describe('InvoiceSuccess', () => {
  const PDF_BASE64 = 'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK';

  const createSuccess = () =>
    new InvoiceSuccess(
      PDF_BASE64,
      'invoice-2026-001.pdf',
      { format_used: 'zugferd', profile: 'EN16931', version: '2.3' },
      { remaining: 499, plan: 'starter' }
    );

  it('has success=true', () => {
    expect(createSuccess().success).toBe(true);
  });

  it('stores format info', () => {
    const s = createSuccess();
    expect(s.format.format_used).toBe('zugferd');
    expect(s.format.profile).toBe('EN16931');
  });

  it('stores account info', () => {
    expect(createSuccess().account?.remaining).toBe(499);
  });

  describe('toUint8Array()', () => {
    it('decodes base64 to PDF bytes', () => {
      const bytes = createSuccess().toUint8Array();
      expect(bytes).toBeInstanceOf(Uint8Array);
      expect(bytes[0]).toBe(0x25); // %
      expect(bytes[1]).toBe(0x50); // P
      expect(bytes[2]).toBe(0x44); // D
      expect(bytes[3]).toBe(0x46); // F
    });
  });

  describe('toDataUrl()', () => {
    it('returns data URL with correct prefix', () => {
      expect(createSuccess().toDataUrl()).toMatch(/^data:application\/pdf;base64,/);
    });
  });

  describe('toBlob()', () => {
    it('creates Blob with application/pdf type', () => {
      const blob = createSuccess().toBlob();
      expect(blob).toBeInstanceOf(Blob);
      expect(blob.type).toBe('application/pdf');
    });
  });
});
