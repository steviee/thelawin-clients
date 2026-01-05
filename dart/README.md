# Envoice Dart SDK

Official Dart SDK for [envoice.dev](https://envoice.dev) - Generate ZUGFeRD/Factur-X compliant invoices with a simple API.

**Requires Dart 3.0+**

## Installation

```yaml
dependencies:
  envoice: ^0.1.0
```

## Quick Start

```dart
import 'package:envoice/envoice.dart';

void main() async {
  final client = EnvoiceClient('env_sandbox_xxx');

  final result = await client.invoice()
      .number('2026-001')
      .date('2026-01-15')
      .seller(Party(
        name: 'Acme GmbH',
        vatId: 'DE123456789',
        street: 'Hauptstraße 1',
        city: 'Berlin',
        postalCode: '10115',
        country: 'DE',
      ))
      .buyer(Party(
        name: 'Customer AG',
        city: 'München',
        country: 'DE',
      ))
      .addItem(LineItem(
        description: 'Consulting Services',
        quantity: 8,
        unit: 'HUR',
        unitPrice: 150.00,
        vatRate: 19.0,
      ))
      .logoFile('./logo.png', widthMm: 30)
      .template('minimal')
      .generate();

  if (result.isSuccess) {
    final success = result as InvoiceSuccess;
    await success.savePdf('./invoices/2026-001.pdf');
    print('Generated: ${success.filename}');
    print('Validation: ${success.validation.profile}');
  } else {
    final failure = result as InvoiceFailure;
    for (final error in failure.errors) {
      print('${error.path}: ${error.message}');
    }
  }

  client.close();
}
```

## API Reference

### EnvoiceClient

```dart
final client = EnvoiceClient(
  'env_sandbox_xxx',
  apiUrl: 'https://api.envoice.dev',  // optional
  timeout: Duration(seconds: 30),      // optional
);
```

### InvoiceBuilder

```dart
client.invoice()
    .number(value)                    // Required
    .date(value)                      // String YYYY-MM-DD, required
    .dateTime(value)                  // DateTime
    .dueDate(value)                   // String
    .seller(party)                    // Party, required
    .buyer(party)                     // Party, required
    .addItem(item)                    // LineItem
    .items(list)                      // Set all items
    .payment(info)                    // PaymentInfo
    .currency(value)                  // Default: 'EUR'
    .template('minimal' | 'classic' | 'compact')
    .locale(value)                    // 'de', 'en', 'fr', 'es', 'it'
    .logoFile(path, widthMm:)         // async
    .logoBase64(base64, widthMm:)
    .footerText(text)
    .accentColor(hex)
    .generate()                       // async
```

### Result Handling

```dart
if (result.isSuccess) {
  final success = result as InvoiceSuccess;
  await success.savePdf('./invoice.pdf');
  final bytes = success.toBytes();
  final dataUrl = success.toDataUrl();
} else {
  final failure = result as InvoiceFailure;
  failure.errors.forEach((e) => print(e.message));
}
```

## Error Handling

```dart
try {
  final result = await client.invoice().number('001').generate();
  // ...
} on EnvoiceQuotaExceededException catch (e) {
  print('Quota exceeded: $e');
} on EnvoiceNetworkException catch (e) {
  print('Network error: $e');
} on EnvoiceApiException catch (e) {
  print('API error ${e.statusCode}: $e');
}
```

## Flutter

This SDK is fully compatible with Flutter. Use it in your Flutter apps to generate invoices.

## License

MIT
