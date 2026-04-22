export interface Party {
  name: string;
  street?: string;
  city?: string;
  postalCode?: string;
  country?: string;
  vatId?: string;
  email?: string;
  phone?: string;
  peppolId?: string;
  codiceFiscale?: string;
  codiceDestinatario?: string;
  pec?: string;
}

export interface LineItem {
  description: string;
  quantity: number;
  unit?: string;
  unitPrice: number;
  vatRate?: number;
  natura?: string;
}

export interface PaymentInfo {
  iban?: string;
  bic?: string;
  terms?: string;
  reference?: string;
}

export interface Customization {
  logoBase64?: string;
  logoWidthMm?: number;
  footerText?: string;
  accentColor?: string;
}

export type InvoiceFormat =
  | 'auto'
  | 'zugferd'
  | 'facturx'
  | 'xrechnung'
  | 'ubl'
  | 'cii'
  | 'peppol'
  | 'fatturapa'
  | 'pdf';

export type InvoiceProfile =
  | 'minimum'
  | 'basic_wl'
  | 'basic'
  | 'en16931'
  | 'extended';

export type InvoiceTemplate = 'minimal' | 'classic' | 'compact';

export type InvoiceLocale = 'de' | 'en' | 'fr' | 'es' | 'it';

export interface InvoiceData {
  number: string;
  date: string;
  dueDate?: string;
  seller: Party;
  buyer: Party;
  items: LineItem[];
  payment?: PaymentInfo;
  currency?: string;
  notes?: string;
  leitwegId?: string;
  buyerReference?: string;
  tipoDocumento?: string;
}

export interface GenerateRequest {
  format?: InvoiceFormat;
  profile?: InvoiceProfile;
  template?: InvoiceTemplate;
  locale?: InvoiceLocale | string;
  invoice: InvoiceData;
  customization?: Customization;
}

export interface FormatInfo {
  format_used: string;
  profile?: string;
  version?: string;
  format_reason?: string;
  warnings?: LegalWarning[];
}

export interface LegalWarning {
  code: string;
  message: string;
  legal_basis: string;
  severity?: 'info' | 'warning';
}

export interface AccountInfo {
  remaining: number;
  plan: string;
  overage_count?: number;
  overage_allowed?: number;
  topup_balance?: number;
  warning?: string;
}

export interface GenerateResponse {
  pdf_base64: string;
  filename: string;
  format: FormatInfo;
  account?: AccountInfo;
}

export interface ValidationError {
  path: string;
  code: string;
  message: string;
  severity?: 'error' | 'warning';
}

export interface ErrorResponse {
  error: string;
  message?: string;
  details?: ValidationError[];
}

export interface DryRunResponse {
  valid: boolean;
  format: FormatInfo;
  errors: string[];
}

export interface RetrieveRequest {
  data_base64: string;
  content_type?: string;
  include_source_xml?: boolean;
}

export interface DetectedFormat {
  detected_format: string;
  profile?: string;
  version?: string;
  xml_type?: string;
  has_pdf?: boolean;
}

export interface RetrieveError {
  code: string;
  message: string;
  path?: string;
  severity?: 'error' | 'warning';
}

export interface RetrieveResponse {
  valid: boolean;
  format: DetectedFormat;
  invoice?: InvoiceData;
  source_xml_base64?: string;
  transaction_id: string;
  errors: RetrieveError[];
  warnings: RetrieveError[];
  locale?: string;
}

export type InvoiceResult =
  | { success: true; pdfBase64: string; filename: string; format: FormatInfo; account?: AccountInfo }
  | { success: false; errors: ValidationError[] };
