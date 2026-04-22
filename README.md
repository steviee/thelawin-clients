# thelawin.dev Client Libraries

Official client libraries for the [thelawin.dev](https://thelawin.dev) ZUGFeRD/Factur-X E-Invoicing API.

Generate EU-compliant e-invoices with a simple, consistent API across all languages.

## Available SDKs

| Language | Package | Install |
|----------|---------|---------|
| **TypeScript/JavaScript** | [@thelawin/sdk](./typescript) | `npm install @thelawin/sdk` |
| **Python** | [thelawin](./python) | `pip install thelawin` |
| **Ruby** | [thelawin](./ruby) | `gem install thelawin` |
| **Kotlin** | [dev.thelawin:sdk](./kotlin) | Maven Central / Gradle |
| **Java** | [dev.thelawin:sdk](./java) | Maven Central |
| **Swift** | [Thelawin](./swift) | Swift Package Manager |
| **Dart** | [thelawin](./dart) | `dart pub add thelawin` |
| **C#** | [Thelawin](./csharp) | `dotnet add package Thelawin` |

## Quick Start

All SDKs share the same fluent API design:

```javascript
// JavaScript/TypeScript
import { ThelawinClient } from '@thelawin/sdk';

const client = new ThelawinClient('env_sandbox_demo');

const result = await client.invoice()
  .number('2026-001')
  .date('2026-01-15')
  .format('zugferd')
  .seller({ name: 'Acme GmbH', vatId: 'DE123456789', city: 'Berlin', country: 'DE' })
  .buyer({ name: 'Customer AG', city: 'Munich', country: 'DE' })
  .addItem({ description: 'Consulting', quantity: 8, unit: 'HUR', unitPrice: 150 })
  .template('minimal')
  .generate();

if (result.success) {
  result.downloadPdf();  // Browser: triggers download
} else {
  result.errors.forEach(e => console.error(`${e.path}: ${e.message}`));
}
```

## Features

- **9 Formats** - ZUGFeRD, Factur-X, XRechnung, Peppol, FatturaPA, UBL, CII, PDF
- **Fluent Builder API** - Chain methods to build invoices
- **Retrieve** - Extract invoice data from existing PDFs/XMLs
- **Logo Support** - Load logos from files or URLs (auto Base64 encoding)
- **Error Handling** - Detailed validation errors with JSON paths
- **Type Safety** - Full TypeScript/type hint support
- **Browser + Server** - Works in browsers and server environments

## API Key

Get your API key at [thelawin.dev/signup](https://thelawin.dev/signup)

- **Demo key** (`env_sandbox_demo`): Free, no account needed, watermarked
- **Sandbox keys** (`env_sandbox_*`): Free, 100 credits/month, watermarked
- **Live keys** (`env_live_*`): Production use, requires paid plan

## Documentation

- [API Documentation](https://docs.thelawin.dev)
- [Getting Started](https://docs.thelawin.dev/guide/getting-started)
- [Formats](https://docs.thelawin.dev/guide/formats)
- [Templates](https://docs.thelawin.dev/guide/templates)

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## License

MIT License - see [LICENSE](./LICENSE) for details.
