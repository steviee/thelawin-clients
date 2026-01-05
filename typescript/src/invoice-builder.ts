import type {
  Party,
  LineItem,
  PaymentInfo,
  Customization,
  InvoiceData,
  GenerateRequest,
  InvoiceResult,
  ValidationResult,
  AccountInfo,
} from './types';
import type { EnvoiceClient } from './client';

/**
 * Result object returned after successful invoice generation
 */
export class InvoiceSuccess {
  public readonly success = true as const;
  public readonly pdfBase64: string;
  public readonly filename: string;
  public readonly validation: ValidationResult;
  public readonly account?: AccountInfo;

  constructor(
    pdfBase64: string,
    filename: string,
    validation: ValidationResult,
    account?: AccountInfo
  ) {
    this.pdfBase64 = pdfBase64;
    this.filename = filename;
    this.validation = validation;
    this.account = account;
  }

  /**
   * Download the PDF (browser only)
   */
  downloadPdf(customFilename?: string): void {
    if (typeof window === 'undefined') {
      throw new Error('downloadPdf() is only available in browser environments');
    }

    const link = document.createElement('a');
    link.href = `data:application/pdf;base64,${this.pdfBase64}`;
    link.download = customFilename || this.filename;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  }

  /**
   * Open PDF in a new browser tab (browser only)
   */
  openInNewTab(): void {
    if (typeof window === 'undefined') {
      throw new Error('openInNewTab() is only available in browser environments');
    }

    const blob = this.toBlob();
    const url = URL.createObjectURL(blob);
    window.open(url, '_blank');
  }

  /**
   * Convert to Blob (browser only)
   */
  toBlob(): Blob {
    const bytes = atob(this.pdfBase64);
    const buffer = new Uint8Array(bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      buffer[i] = bytes.charCodeAt(i);
    }
    return new Blob([buffer], { type: 'application/pdf' });
  }

  /**
   * Get the PDF as a Uint8Array
   */
  toUint8Array(): Uint8Array {
    const bytes = atob(this.pdfBase64);
    const buffer = new Uint8Array(bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      buffer[i] = bytes.charCodeAt(i);
    }
    return buffer;
  }

  /**
   * Get the PDF as a data URL
   */
  toDataUrl(): string {
    return `data:application/pdf;base64,${this.pdfBase64}`;
  }
}

/**
 * Fluent builder for creating invoices
 */
export class InvoiceBuilder {
  private client: EnvoiceClient;
  private data: Partial<InvoiceData> = {};
  private template: GenerateRequest['template'] = 'minimal';
  private locale = 'en';
  private customization: Customization = {};

  constructor(client: EnvoiceClient) {
    this.client = client;
  }

  /**
   * Set the invoice number
   */
  number(value: string): this {
    this.data.number = value;
    return this;
  }

  /**
   * Set the invoice date (ISO format: YYYY-MM-DD)
   */
  date(value: string | Date): this {
    if (value instanceof Date) {
      this.data.date = value.toISOString().split('T')[0];
    } else {
      this.data.date = value;
    }
    return this;
  }

  /**
   * Set the due date (ISO format: YYYY-MM-DD)
   */
  dueDate(value: string | Date): this {
    if (value instanceof Date) {
      this.data.dueDate = value.toISOString().split('T')[0];
    } else {
      this.data.dueDate = value;
    }
    return this;
  }

  /**
   * Set the seller information
   */
  seller(party: Party): this {
    this.data.seller = party;
    return this;
  }

  /**
   * Set the buyer information
   */
  buyer(party: Party): this {
    this.data.buyer = party;
    return this;
  }

  /**
   * Add a line item to the invoice
   */
  addItem(item: LineItem): this {
    if (!this.data.items) {
      this.data.items = [];
    }
    this.data.items.push({
      ...item,
      unit: item.unit || 'C62',
      vatRate: item.vatRate ?? 19.0,
    });
    return this;
  }

  /**
   * Set multiple line items at once
   */
  items(items: LineItem[]): this {
    this.data.items = items.map(item => ({
      ...item,
      unit: item.unit || 'C62',
      vatRate: item.vatRate ?? 19.0,
    }));
    return this;
  }

  /**
   * Set payment information
   */
  payment(info: PaymentInfo): this {
    this.data.payment = info;
    return this;
  }

  /**
   * Set the currency (default: EUR)
   */
  currency(value: string): this {
    this.data.currency = value;
    return this;
  }

  /**
   * Set the template (minimal, classic, compact)
   */
  templateType(value: GenerateRequest['template']): this {
    this.template = value;
    return this;
  }

  // Alias for templateType
  template(value: GenerateRequest['template']): this {
    return this.templateType(value);
  }

  /**
   * Set the locale for labels (de, en, fr, es, it)
   */
  localeCode(value: string): this {
    this.locale = value;
    return this;
  }

  /**
   * Set a logo from a URL (browser: fetches and encodes)
   */
  async logoFromUrl(url: string, widthMm?: number): Promise<this> {
    const response = await fetch(url);
    const blob = await response.blob();
    const base64 = await this.blobToBase64(blob);
    this.customization.logoBase64 = base64;
    if (widthMm) this.customization.logoWidthMm = widthMm;
    return this;
  }

  /**
   * Set a logo from Base64 string
   */
  logoBase64(base64: string, widthMm?: number): this {
    this.customization.logoBase64 = base64;
    if (widthMm) this.customization.logoWidthMm = widthMm;
    return this;
  }

  /**
   * Set a logo from a Blob or File (browser only)
   */
  async logoFromBlob(blob: Blob, widthMm?: number): Promise<this> {
    const base64 = await this.blobToBase64(blob);
    this.customization.logoBase64 = base64;
    if (widthMm) this.customization.logoWidthMm = widthMm;
    return this;
  }

  /**
   * Set footer text
   */
  footerText(text: string): this {
    this.customization.footerText = text;
    return this;
  }

  /**
   * Set accent color (hex code)
   */
  accentColor(color: string): this {
    this.customization.accentColor = color;
    return this;
  }

  /**
   * Generate the invoice
   */
  async generate(): Promise<InvoiceResult> {
    // Validate required fields
    if (!this.data.number) {
      return {
        success: false,
        errors: [{ path: '$.invoice.number', code: 'REQUIRED', message: 'Invoice number is required' }],
      };
    }
    if (!this.data.date) {
      return {
        success: false,
        errors: [{ path: '$.invoice.date', code: 'REQUIRED', message: 'Invoice date is required' }],
      };
    }
    if (!this.data.seller) {
      return {
        success: false,
        errors: [{ path: '$.invoice.seller', code: 'REQUIRED', message: 'Seller information is required' }],
      };
    }
    if (!this.data.buyer) {
      return {
        success: false,
        errors: [{ path: '$.invoice.buyer', code: 'REQUIRED', message: 'Buyer information is required' }],
      };
    }
    if (!this.data.items || this.data.items.length === 0) {
      return {
        success: false,
        errors: [{ path: '$.invoice.items', code: 'REQUIRED', message: 'At least one line item is required' }],
      };
    }

    const request: GenerateRequest = {
      template: this.template,
      locale: this.locale,
      invoice: this.data as InvoiceData,
      customization: Object.keys(this.customization).length > 0 ? this.customization : undefined,
    };

    return this.client.generateInvoice(request);
  }

  private blobToBase64(blob: Blob): Promise<string> {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => {
        const result = reader.result as string;
        // Remove data URL prefix if present
        const base64 = result.includes(',') ? result.split(',')[1] : result;
        resolve(base64);
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }
}
