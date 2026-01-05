# @envoice/sdk

Official TypeScript/JavaScript SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

## Installation

```bash
npm install @envoice/sdk
# or
yarn add @envoice/sdk
# or
pnpm add @envoice/sdk
```

## Quick Start

### Browser

```typescript
import { EnvoiceClient } from '@envoice/sdk';

const client = new EnvoiceClient('env_sandbox_xxx');

const result = await client.invoice()
  .number('2026-001')
  .date('2026-01-15')
  .seller({
    name: 'Acme GmbH',
    vatId: 'DE123456789',
    street: 'Hauptstraße 1',
    city: 'Berlin',
    postalCode: '10115',
    country: 'DE'
  })
  .buyer({
    name: 'Customer AG',
    city: 'München',
    country: 'DE'
  })
  .addItem({
    description: 'Consulting Services',
    quantity: 8,
    unit: 'HUR',
    unitPrice: 150.00,
    vatRate: 19.0
  })
  .template('minimal')
  .generate();

if (result.success) {
  // Download the PDF
  result.downloadPdf();

  // Or open in new tab
  result.openInNewTab();

  // Access validation info
  console.log(result.validation.profile); // "EN16931"
  console.log(result.validation.version); // "2.3.2"
} else {
  // Handle validation errors
  result.errors.forEach(error => {
    console.error(`${error.path}: ${error.message}`);
  });
}
```

### Node.js

```typescript
import { EnvoiceClient } from '@envoice/sdk';
import { savePdf, withNodeSupport } from '@envoice/sdk/node';

const client = new EnvoiceClient('env_live_xxx');

// Use withNodeSupport for file operations
const builder = withNodeSupport(client.invoice());

const result = await builder
  .logoFile('./logo.png', 30)  // Load logo from file, 30mm width
  .then(b => b
    .number('2026-001')
    .date('2026-01-15')
    .seller({ name: 'Acme GmbH', vatId: 'DE123456789' })
    .buyer({ name: 'Customer AG' })
    .addItem({ description: 'Consulting', quantity: 8, unitPrice: 150 })
    .generate()
  );

if (result.success) {
  // Save to file
  await savePdf(result.pdfBase64, './invoices/2026-001.pdf');
  console.log(`Saved: ${result.filename}`);
}
```

## API Reference

### EnvoiceClient

```typescript
const client = new EnvoiceClient(apiKey: string, options?: {
  apiUrl?: string;    // Default: 'https://api.envoice.dev'
  timeout?: number;   // Default: 30000 (30 seconds)
  fetch?: typeof fetch; // Custom fetch implementation
});
```

### InvoiceBuilder

Fluent builder for creating invoices:

```typescript
client.invoice()
  .number(value: string)              // Invoice number (required)
  .date(value: string | Date)         // Invoice date YYYY-MM-DD (required)
  .dueDate(value: string | Date)      // Due date YYYY-MM-DD
  .seller(party: Party)               // Seller info (required)
  .buyer(party: Party)                // Buyer info (required)
  .addItem(item: LineItem)            // Add line item (at least one required)
  .items(items: LineItem[])           // Set all items at once
  .payment(info: PaymentInfo)         // Payment details (IBAN, BIC, terms)
  .currency(value: string)            // Default: 'EUR'
  .template(value: 'minimal' | 'classic' | 'compact')
  .localeCode(value: string)          // 'de', 'en', 'fr', 'es', 'it'
  .logoBase64(base64: string, widthMm?: number)
  .logoFromUrl(url: string, widthMm?: number)  // Browser: fetches and encodes
  .logoFromBlob(blob: Blob, widthMm?: number)  // Browser only
  .footerText(text: string)
  .accentColor(hex: string)           // e.g., '#8b5cf6'
  .generate(): Promise<InvoiceResult>
```

### Types

```typescript
interface Party {
  name: string;
  street?: string;
  city?: string;
  postalCode?: string;
  country?: string;    // ISO 3166-1 alpha-2 (e.g., 'DE')
  vatId?: string;
  email?: string;
  phone?: string;
}

interface LineItem {
  description: string;
  quantity: number;
  unit?: string;       // UN/ECE Rec 20 code, default: 'C62' (piece)
  unitPrice: number;
  vatRate?: number;    // Default: 19.0
}

interface PaymentInfo {
  iban?: string;
  bic?: string;
  terms?: string;
  reference?: string;
}

type InvoiceResult =
  | { success: true; pdfBase64: string; filename: string; validation: ValidationResult; account?: AccountInfo }
  | { success: false; errors: ValidationError[] };
```

### Common Unit Codes

| Code | Description |
|------|-------------|
| `C62` | Piece (default) |
| `HUR` | Hour |
| `DAY` | Day |
| `MON` | Month |
| `KGM` | Kilogram |
| `MTR` | Meter |
| `LTR` | Liter |

### Direct API Methods

```typescript
// Generate invoice directly (without builder)
await client.generateInvoice(request: GenerateRequest): Promise<InvoiceResult>

// Validate an existing PDF
await client.validate(pdfBase64: string): Promise<ValidationResult>

// Get account info (quota, plan)
await client.getAccount(): Promise<AccountInfo>
```

## Error Handling

```typescript
import {
  EnvoiceError,
  EnvoiceApiError,
  EnvoiceValidationError,
  EnvoiceNetworkError,
  EnvoiceQuotaExceededError
} from '@envoice/sdk';

try {
  const result = await client.invoice()
    .number('2026-001')
    .generate();

  if (!result.success) {
    // Validation errors (422)
    result.errors.forEach(e => console.log(e.message));
  }
} catch (error) {
  if (error instanceof EnvoiceQuotaExceededError) {
    console.log('Quota exceeded, upgrade your plan');
  } else if (error instanceof EnvoiceNetworkError) {
    console.log('Network error:', error.message);
  } else if (error instanceof EnvoiceApiError) {
    console.log(`API error ${error.statusCode}: ${error.message}`);
  }
}
```

## Browser Usage (Script Tag)

```html
<script type="module">
  import { EnvoiceClient } from 'https://esm.sh/@envoice/sdk';

  const client = new EnvoiceClient('env_sandbox_xxx');
  // ... use as shown above
</script>
```

## License

MIT
