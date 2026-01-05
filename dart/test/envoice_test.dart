import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:envoice/envoice.dart';

void main() {
  group('EnvoiceClient', () {
    test('requires API key', () {
      expect(() => EnvoiceClient(''), throwsArgumentError);
    });

    test('creates with valid API key', () {
      final client = EnvoiceClient('env_sandbox_test');
      expect(client, isNotNull);
      client.close();
    });

    test('invoice returns builder', () {
      final client = EnvoiceClient('env_sandbox_test');
      final builder = client.invoice();
      expect(builder, isA<InvoiceBuilder>());
      client.close();
    });
  });

  group('InvoiceBuilder', () {
    late EnvoiceClient client;

    setUp(() {
      client = EnvoiceClient('env_sandbox_test');
    });

    tearDown(() {
      client.close();
    });

    test('validates required fields', () async {
      final result = await client.invoice().generate();

      expect(result.isFailure, isTrue);
      final failure = result as InvoiceFailure;
      expect(failure.errors.any((e) => e.path == r'$.invoice.number'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.date'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.seller'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.buyer'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.items'), isTrue);
    });

    test('fluent interface returns builder', () {
      final builder = client.invoice();

      expect(builder.number('2026-001'), same(builder));
      expect(builder.date('2026-01-15'), same(builder));
      expect(builder.dueDate('2026-02-15'), same(builder));
      expect(builder.currency('EUR'), same(builder));
      expect(builder.template('minimal'), same(builder));
      expect(builder.locale('de'), same(builder));
      expect(builder.footerText('Thanks!'), same(builder));
      expect(builder.accentColor('#8b5cf6'), same(builder));
    });

    test('accepts party objects', () {
      final seller = Party(
        name: 'Acme GmbH',
        vatId: 'DE123456789',
        city: 'Berlin',
        country: 'DE',
      );

      final buyer = Party(
        name: 'Customer AG',
        city: 'München',
        country: 'DE',
      );

      final builder = client.invoice().seller(seller).buyer(buyer);
      expect(builder, isNotNull);
    });

    test('accepts line items', () {
      final item = LineItem(
        description: 'Consulting',
        quantity: 8,
        unit: 'HUR',
        unitPrice: 150.0,
        vatRate: 19.0,
      );

      final builder = client.invoice().addItem(item);
      expect(builder, isNotNull);
    });
  });

  group('InvoiceSuccess', () {
    test('provides PDF methods', () {
      final success = InvoiceSuccess(
        pdfBase64: 'JVBERi0xLjQKJeLjz9MKMSAwIG9iago8PC9UeXBlL0NhdGFsb2c+PgplbmRvYmoKdHJhaWxlcgo8PC9Sb290IDEgMCBSPj4KJSVFT0YK',
        filename: 'invoice-2026-001.pdf',
        validation: ValidationResult(
          status: 'valid',
          profile: 'EN16931',
          version: '2.3.2',
        ),
        account: AccountInfo(remaining: 499, plan: 'starter'),
      );

      expect(success.isSuccess, isTrue);
      expect(success.filename, equals('invoice-2026-001.pdf'));
      expect(success.validation.profile, equals('EN16931'));
      expect(success.account?.remaining, equals(499));

      final bytes = success.toBytes();
      expect(bytes, isA<Uint8List>());
      expect(bytes.isNotEmpty, isTrue);
      expect(utf8.decode(bytes.sublist(0, 4)), equals('%PDF'));

      final dataUrl = success.toDataUrl();
      expect(dataUrl, startsWith('data:application/pdf;base64,'));
    });
  });

  group('InvoiceFailure', () {
    test('contains errors', () {
      final failure = InvoiceFailure([
        ValidationError(
          path: r'$.invoice.number',
          code: 'REQUIRED',
          message: 'Invoice number is required',
        ),
      ]);

      expect(failure.isSuccess, isFalse);
      expect(failure.isFailure, isTrue);
      expect(failure.errors.length, equals(1));
      expect(failure.errors[0].path, equals(r'$.invoice.number'));
    });
  });
}
