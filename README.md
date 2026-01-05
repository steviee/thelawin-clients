# envoice.dev Client Libraries

Official client libraries for the [envoice.dev](https://envoice.dev) ZUGFeRD/Factur-X API.

Generate EU-compliant e-invoices with a simple, consistent API across all languages.

## Available SDKs

| Language | Package | Install |
|----------|---------|---------|
| **TypeScript/JavaScript** | [@envoice/sdk](./typescript) | `npm install @envoice/sdk` |
| **Python** | [envoice](./python) | `pip install envoice` |
| **Ruby** | [envoice](./ruby) | `gem install envoice` |
| **Swift** | [Envoice](./swift) | Swift Package Manager |
| **Dart** | [envoice](./dart) | `dart pub add envoice` |
| **Java** | [dev.envoice:sdk](./java) | Maven Central |
| **Kotlin** | [dev.envoice:sdk](./kotlin) | Maven Central / Gradle |
| **C#** | [Envoice](./csharp) | `dotnet add package Envoice` |

## Quick Start

All SDKs share the same fluent API design:

```javascript
// JavaScript/TypeScript
import { EnvoiceClient } from '@envoice/sdk';

const client = new EnvoiceClient('env_sandbox_xxx');

const result = await client.invoice()
  .number('2026-001')
  .date('2026-01-15')
  .seller({ name: 'Acme GmbH', vatId: 'DE123456789', city: 'Berlin', country: 'DE' })
  .buyer({ name: 'Customer AG', city: 'Munich', country: 'DE' })
  .addItem({ description: 'Consulting', quantity: 8, unit: 'HUR', unitPrice: 150 })
  .template('minimal')
  .generate();

if (result.success) {
  result.downloadPdf();  // Browser: triggers download
  // or: await result.savePdf('./invoice.pdf');  // Node.js
} else {
  result.errors.forEach(e => console.error(`${e.path}: ${e.message}`));
}
```

## Features

- **Fluent Builder API** - Chain methods to build invoices
- **Logo Support** - Load logos from files or URLs (auto Base64 encoding)
- **Error Handling** - Detailed validation errors with JSON paths
- **Type Safety** - Full TypeScript/type hint support
- **Browser + Server** - Works in browsers and server environments

## API Key

Get your API key at [envoice.dev/api-keys](https://envoice.dev/api-keys)

- **Sandbox keys** (`env_sandbox_*`): Free, unlimited, watermarked PDFs
- **Live keys** (`env_live_*`): Production use, requires paid plan

## Documentation

- [API Documentation](https://envoice.dev/docs)
- [Getting Started](https://envoice.dev/docs/getting-started)
- [Templates](https://envoice.dev/docs/templates)
- [Unit Codes](https://envoice.dev/docs/units)

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](./LICENSE) for details.
