import type {
  Party,
  LineItem,
  PaymentInfo,
  Customization,
  InvoiceData,
  GenerateRequest,
  InvoiceResult,
  FormatInfo,
  AccountInfo,
  InvoiceFormat,
  InvoiceProfile,
  InvoiceTemplate,
  InvoiceLocale,
} from './types';
import type { ThelawinClient } from './client';

export class InvoiceSuccess {
  public readonly success = true as const;
  public readonly pdfBase64: string;
  public readonly filename: string;
  public readonly format: FormatInfo;
  public readonly account?: AccountInfo;

  constructor(
    pdfBase64: string,
    filename: string,
    format: FormatInfo,
    account?: AccountInfo
  ) {
    this.pdfBase64 = pdfBase64;
    this.filename = filename;
    this.format = format;
    this.account = account;
  }

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

  openInNewTab(): void {
    if (typeof window === 'undefined') {
      throw new Error('openInNewTab() is only available in browser environments');
    }

    const blob = this.toBlob();
    const url = URL.createObjectURL(blob);
    window.open(url, '_blank');
  }

  toBlob(): Blob {
    const bytes = atob(this.pdfBase64);
    const buffer = new Uint8Array(bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      buffer[i] = bytes.charCodeAt(i);
    }
    return new Blob([buffer], { type: 'application/pdf' });
  }

  toUint8Array(): Uint8Array {
    const bytes = atob(this.pdfBase64);
    const buffer = new Uint8Array(bytes.length);
    for (let i = 0; i < bytes.length; i++) {
      buffer[i] = bytes.charCodeAt(i);
    }
    return buffer;
  }

  toDataUrl(): string {
    return `data:application/pdf;base64,${this.pdfBase64}`;
  }
}

export class InvoiceBuilder {
  private client: ThelawinClient;
  private data: Partial<InvoiceData> = {};
  private _format: InvoiceFormat = 'auto';
  private _profile: InvoiceProfile = 'en16931';
  private _template: InvoiceTemplate = 'minimal';
  private _locale: string = 'en';
  private customization: Customization = {};

  constructor(client: ThelawinClient) {
    this.client = client;
  }

  number(value: string): this {
    this.data.number = value;
    return this;
  }

  date(value: string | Date): this {
    this.data.date = value instanceof Date ? value.toISOString().split('T')[0] : value;
    return this;
  }

  dueDate(value: string | Date): this {
    this.data.dueDate = value instanceof Date ? value.toISOString().split('T')[0] : value;
    return this;
  }

  seller(party: Party): this {
    this.data.seller = party;
    return this;
  }

  buyer(party: Party): this {
    this.data.buyer = party;
    return this;
  }

  addItem(item: LineItem): this {
    if (!this.data.items) this.data.items = [];
    this.data.items.push({
      ...item,
      unit: item.unit || 'C62',
      vatRate: item.vatRate ?? 19.0,
    });
    return this;
  }

  items(items: LineItem[]): this {
    this.data.items = items.map(item => ({
      ...item,
      unit: item.unit || 'C62',
      vatRate: item.vatRate ?? 19.0,
    }));
    return this;
  }

  payment(info: PaymentInfo): this {
    this.data.payment = info;
    return this;
  }

  currency(value: string): this {
    this.data.currency = value;
    return this;
  }

  notes(value: string): this {
    this.data.notes = value;
    return this;
  }

  format(value: InvoiceFormat): this {
    this._format = value;
    return this;
  }

  profile(value: InvoiceProfile): this {
    this._profile = value;
    return this;
  }

  template(value: InvoiceTemplate): this {
    this._template = value;
    return this;
  }

  locale(value: InvoiceLocale | string): this {
    this._locale = value;
    return this;
  }

  leitwegId(value: string): this {
    this.data.leitwegId = value;
    return this;
  }

  buyerReference(value: string): this {
    this.data.buyerReference = value;
    return this;
  }

  tipoDocumento(value: string): this {
    this.data.tipoDocumento = value;
    return this;
  }

  async logoFromUrl(url: string, widthMm?: number): Promise<this> {
    const response = await fetch(url);
    const blob = await response.blob();
    const base64 = await this.blobToBase64(blob);
    this.customization.logoBase64 = base64;
    if (widthMm) this.customization.logoWidthMm = widthMm;
    return this;
  }

  logoBase64(base64: string, widthMm?: number): this {
    this.customization.logoBase64 = base64;
    if (widthMm) this.customization.logoWidthMm = widthMm;
    return this;
  }

  async logoFromBlob(blob: Blob, widthMm?: number): Promise<this> {
    const base64 = await this.blobToBase64(blob);
    this.customization.logoBase64 = base64;
    if (widthMm) this.customization.logoWidthMm = widthMm;
    return this;
  }

  footerText(text: string): this {
    this.customization.footerText = text;
    return this;
  }

  accentColor(color: string): this {
    this.customization.accentColor = color;
    return this;
  }

  async generate(): Promise<InvoiceResult> {
    if (!this.data.number) {
      return { success: false, errors: [{ path: '$.invoice.number', code: 'REQUIRED', message: 'Invoice number is required' }] };
    }
    if (!this.data.date) {
      return { success: false, errors: [{ path: '$.invoice.date', code: 'REQUIRED', message: 'Invoice date is required' }] };
    }
    if (!this.data.seller) {
      return { success: false, errors: [{ path: '$.invoice.seller', code: 'REQUIRED', message: 'Seller information is required' }] };
    }
    if (!this.data.buyer) {
      return { success: false, errors: [{ path: '$.invoice.buyer', code: 'REQUIRED', message: 'Buyer information is required' }] };
    }
    if (!this.data.items || this.data.items.length === 0) {
      return { success: false, errors: [{ path: '$.invoice.items', code: 'REQUIRED', message: 'At least one line item is required' }] };
    }

    const request: GenerateRequest = {
      format: this._format,
      profile: this._profile,
      template: this._template,
      locale: this._locale,
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
        const base64 = result.includes(',') ? result.split(',')[1] : result;
        resolve(base64);
      };
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
  }
}
