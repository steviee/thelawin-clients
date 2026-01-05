/**
 * Party (seller or buyer) information
 */
export interface Party {
  name: string;
  street?: string;
  city?: string;
  postalCode?: string;
  country?: string;
  vatId?: string;
  email?: string;
  phone?: string;
}

/**
 * Line item in an invoice
 */
export interface LineItem {
  description: string;
  quantity: number;
  unit?: string;
  unitPrice: number;
  vatRate?: number;
}

/**
 * Payment information
 */
export interface PaymentInfo {
  iban?: string;
  bic?: string;
  terms?: string;
  reference?: string;
}

/**
 * Customization options for the invoice PDF
 */
export interface Customization {
  logoBase64?: string;
  logoWidthMm?: number;
  footerText?: string;
  accentColor?: string;
}

/**
 * Complete invoice data structure
 */
export interface InvoiceData {
  number: string;
  date: string;
  dueDate?: string;
  seller: Party;
  buyer: Party;
  items: LineItem[];
  payment?: PaymentInfo;
  currency?: string;
}

/**
 * Request payload for the generate endpoint
 */
export interface GenerateRequest {
  template?: 'minimal' | 'classic' | 'compact';
  locale?: string;
  invoice: InvoiceData;
  customization?: Customization;
}

/**
 * Validation result from the API
 */
export interface ValidationResult {
  status: string;
  profile: string;
  version: string;
  warnings?: string[];
}

/**
 * Account information from the API
 */
export interface AccountInfo {
  remaining: number;
  plan: string;
  overageCount?: number;
  overageAllowed?: number;
  warning?: string;
}

/**
 * Successful API response
 */
export interface GenerateResponse {
  pdf_base64: string;
  filename: string;
  validation: ValidationResult;
  account?: AccountInfo;
}

/**
 * Validation error detail
 */
export interface ValidationError {
  path: string;
  code: string;
  message: string;
  severity?: 'error' | 'warning';
}

/**
 * Error response from the API
 */
export interface ErrorResponse {
  error: string;
  message?: string;
  details?: ValidationError[];
}

/**
 * Result of an invoice generation (success or failure)
 */
export type InvoiceResult =
  | { success: true; pdfBase64: string; filename: string; validation: ValidationResult; account?: AccountInfo }
  | { success: false; errors: ValidationError[] };
