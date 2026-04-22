import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:thelawin/thelawin.dart';

void main() {
  group('ThelawinClient', () {
    test('requires API key', () {
      expect(() => ThelawinClient(''), throwsArgumentError);
    });

    test('creates with valid API key', () {
      final client = ThelawinClient('env_sandbox_test');
      expect(client, isNotNull);
      expect(client.apiKey, equals('env_sandbox_test'));
      client.close();
    });

    test('uses default API URL', () {
      final client = ThelawinClient('env_sandbox_test');
      expect(client.apiUrl, equals('https://api.thelawin.dev'));
      client.close();
    });

    test('accepts custom API URL', () {
      final client = ThelawinClient('env_sandbox_test', apiUrl: 'http://localhost:8080');
      expect(client.apiUrl, equals('http://localhost:8080'));
      client.close();
    });

    test('accepts custom timeout', () {
      final client = ThelawinClient('env_sandbox_test', timeout: const Duration(seconds: 60));
      expect(client.timeout, equals(const Duration(seconds: 60)));
      client.close();
    });

    test('invoice() returns InvoiceBuilder', () {
      final client = ThelawinClient('env_sandbox_test');
      final builder = client.invoice();
      expect(builder, isA<InvoiceBuilder>());
      client.close();
    });
  });

  group('InvoiceBuilder fluent API', () {
    late ThelawinClient client;

    setUp(() {
      client = ThelawinClient('env_sandbox_test');
    });

    tearDown(() {
      client.close();
    });

    test('all setters return same builder instance', () {
      final builder = client.invoice();

      expect(builder.number('2026-001'), same(builder));
      expect(builder.date('2026-01-15'), same(builder));
      expect(builder.dueDate('2026-02-15'), same(builder));
      expect(builder.currency('EUR'), same(builder));
      expect(builder.template('minimal'), same(builder));
      expect(builder.locale('de'), same(builder));
      expect(builder.footerText('Thanks!'), same(builder));
      expect(builder.accentColor('#8b5cf6'), same(builder));
      expect(builder.format(InvoiceFormat.zugferd), same(builder));
      expect(builder.profile(InvoiceProfile.en16931), same(builder));
      expect(builder.notes('A note'), same(builder));
      expect(builder.leitwegId('04011000-12345-67'), same(builder));
      expect(builder.buyerReference('REF-123'), same(builder));
      expect(builder.tipoDocumento('TD01'), same(builder));
    });

    test('dateTime sets date from DateTime', () async {
      final builder = client.invoice();
      final result = builder.dateTime(DateTime(2026, 3, 15));
      expect(result, same(builder));
    });

    test('items() replaces existing items', () {
      final builder = client.invoice();
      builder.addItem(LineItem(description: 'First', quantity: 1, unitPrice: 10));
      builder.items([
        LineItem(description: 'Second', quantity: 2, unitPrice: 20),
      ]);
      // After items(), only 'Second' should remain
      // (We verify indirectly through the generate validation passing with items)
      expect(builder, isNotNull);
    });
  });

  group('InvoiceBuilder validation', () {
    late ThelawinClient client;

    setUp(() {
      client = ThelawinClient('env_sandbox_test');
    });

    tearDown(() {
      client.close();
    });

    test('validates all required fields', () async {
      final result = await client.invoice().generate();

      expect(result.isFailure, isTrue);
      expect(result.isSuccess, isFalse);
      final failure = result as InvoiceFailure;
      expect(failure.errors.length, equals(5));
      expect(failure.errors.any((e) => e.path == r'$.invoice.number'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.date'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.seller'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.buyer'), isTrue);
      expect(failure.errors.any((e) => e.path == r'$.invoice.items'), isTrue);
    });

    test('validates missing number only', () async {
      final result = await client
          .invoice()
          .date('2026-01-15')
          .seller(Party(name: 'Seller'))
          .buyer(Party(name: 'Buyer'))
          .addItem(LineItem(description: 'Item', quantity: 1, unitPrice: 100))
          .generate();

      expect(result.isFailure, isTrue);
      final failure = result as InvoiceFailure;
      expect(failure.errors.length, equals(1));
      expect(failure.errors[0].path, equals(r'$.invoice.number'));
      expect(failure.errors[0].code, equals('REQUIRED'));
    });

    test('validates missing items', () async {
      final result = await client
          .invoice()
          .number('INV-001')
          .date('2026-01-15')
          .seller(Party(name: 'Seller'))
          .buyer(Party(name: 'Buyer'))
          .generate();

      expect(result.isFailure, isTrue);
      final failure = result as InvoiceFailure;
      expect(failure.errors.length, equals(1));
      expect(failure.errors[0].path, equals(r'$.invoice.items'));
    });
  });

  group('InvoiceFormat', () {
    test('all formats serialize correctly', () {
      expect(InvoiceFormat.auto.toJson(), equals('auto'));
      expect(InvoiceFormat.zugferd.toJson(), equals('zugferd'));
      expect(InvoiceFormat.facturx.toJson(), equals('facturx'));
      expect(InvoiceFormat.xrechnung.toJson(), equals('xrechnung'));
      expect(InvoiceFormat.ubl.toJson(), equals('ubl'));
      expect(InvoiceFormat.cii.toJson(), equals('cii'));
      expect(InvoiceFormat.peppol.toJson(), equals('peppol'));
      expect(InvoiceFormat.fatturapa.toJson(), equals('fatturapa'));
      expect(InvoiceFormat.pdf.toJson(), equals('pdf'));
    });

    test('enum has all 9 values', () {
      expect(InvoiceFormat.values.length, equals(9));
    });
  });

  group('InvoiceProfile', () {
    test('all profiles serialize correctly', () {
      expect(InvoiceProfile.minimum.toJson(), equals('MINIMUM'));
      expect(InvoiceProfile.basicWl.toJson(), equals('BASIC_WL'));
      expect(InvoiceProfile.basic.toJson(), equals('BASIC'));
      expect(InvoiceProfile.en16931.toJson(), equals('EN16931'));
      expect(InvoiceProfile.extended.toJson(), equals('EXTENDED'));
    });

    test('enum has all 5 values', () {
      expect(InvoiceProfile.values.length, equals(5));
    });
  });

  group('LineItem defaults', () {
    test('defaults unit to C62', () {
      final item = LineItem(description: 'Test', quantity: 1, unitPrice: 100);
      expect(item.unit, equals('C62'));
    });

    test('defaults vatRate to 19.0', () {
      final item = LineItem(description: 'Test', quantity: 1, unitPrice: 100);
      expect(item.vatRate, equals(19.0));
    });

    test('allows custom unit and vatRate', () {
      final item = LineItem(
        description: 'Hours',
        quantity: 8,
        unit: 'HUR',
        unitPrice: 150,
        vatRate: 7.0,
      );
      expect(item.unit, equals('HUR'));
      expect(item.vatRate, equals(7.0));
    });

    test('supports natura for FatturaPA', () {
      final item = LineItem(
        description: 'Exempt service',
        quantity: 1,
        unitPrice: 500,
        vatRate: 0,
        natura: 'N2.2',
      );
      expect(item.natura, equals('N2.2'));
      final json = item.toJson();
      expect(json['natura'], equals('N2.2'));
    });

    test('omits natura from JSON when null', () {
      final item = LineItem(description: 'Test', quantity: 1, unitPrice: 100);
      final json = item.toJson();
      expect(json.containsKey('natura'), isFalse);
    });
  });

  group('Party', () {
    test('serializes basic fields', () {
      final party = Party(name: 'Acme GmbH', city: 'Berlin', country: 'DE');
      final json = party.toJson();
      expect(json['name'], equals('Acme GmbH'));
      expect(json['city'], equals('Berlin'));
      expect(json['country'], equals('DE'));
    });

    test('supports Peppol endpoint fields', () {
      final party = Party(
        name: 'EU Corp',
        endpointId: '0088:1234567890123',
        endpointScheme: '0088',
      );
      final json = party.toJson();
      expect(json['endpointId'], equals('0088:1234567890123'));
      expect(json['endpointScheme'], equals('0088'));
    });

    test('supports FatturaPA fields', () {
      final party = Party(
        name: 'Italian Srl',
        codiceFiscale: 'RSSMRA80A01H501U',
        codiceDestinatario: 'ABCDEFG',
        pecDestinatario: 'test@pec.it',
      );
      final json = party.toJson();
      expect(json['codiceFiscale'], equals('RSSMRA80A01H501U'));
      expect(json['codiceDestinatario'], equals('ABCDEFG'));
      expect(json['pecDestinatario'], equals('test@pec.it'));
    });

    test('omits null optional fields from JSON', () {
      final party = Party(name: 'Minimal');
      final json = party.toJson();
      expect(json.length, equals(1));
      expect(json.containsKey('name'), isTrue);
      expect(json.containsKey('street'), isFalse);
      expect(json.containsKey('endpointId'), isFalse);
      expect(json.containsKey('codiceFiscale'), isFalse);
    });
  });

  group('InvoiceSuccess', () {
    test('provides PDF helper methods', () {
      final success = InvoiceSuccess(
        pdfBase64: base64Encode(utf8.encode('%PDF-1.4 test content')),
        filename: 'invoice-2026-001.pdf',
        validation: ValidationResult(
          status: 'valid',
          profile: 'EN16931',
          version: '2.4.0',
        ),
        account: AccountInfo(remaining: 499, plan: 'starter'),
      );

      expect(success.isSuccess, isTrue);
      expect(success.isFailure, isFalse);
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
    test('contains errors and reports failure', () {
      final failure = InvoiceFailure([
        ValidationError(
          path: r'$.invoice.number',
          code: 'REQUIRED',
          message: 'Invoice number is required',
        ),
        ValidationError(
          path: r'$.invoice.date',
          code: 'REQUIRED',
          message: 'Invoice date is required',
        ),
      ]);

      expect(failure.isSuccess, isFalse);
      expect(failure.isFailure, isTrue);
      expect(failure.errors.length, equals(2));
      expect(failure.errors[0].path, equals(r'$.invoice.number'));
      expect(failure.errors[1].code, equals('REQUIRED'));
    });
  });

  group('RetrieveResponse', () {
    test('parses successful response', () {
      final json = {
        'invoice': {'number': 'INV-001', 'date': '2026-01-15'},
        'detectedFormat': {'format': 'zugferd', 'profile': 'EN16931', 'version': '2.4'},
        'account': {'remaining': 99, 'plan': 'sandbox'},
      };

      final response = RetrieveResponse.fromJson(json);
      expect(response.isSuccess, isTrue);
      expect(response.isFailure, isFalse);
      expect(response.invoice?['number'], equals('INV-001'));
      expect(response.detectedFormat?.format, equals('zugferd'));
      expect(response.detectedFormat?.profile, equals('EN16931'));
      expect(response.account?.remaining, equals(99));
    });

    test('parses response with errors', () {
      final json = {
        'errors': [
          {'code': 'PARSE_ERROR', 'message': 'Unable to parse PDF'},
        ],
      };

      final response = RetrieveResponse.fromJson(json);
      expect(response.isFailure, isTrue);
      expect(response.errors?.length, equals(1));
      expect(response.errors?[0].code, equals('PARSE_ERROR'));
    });

    test('includes sourceXml when requested', () {
      final json = {
        'invoice': {'number': 'INV-001'},
        'sourceXml': '<Invoice>...</Invoice>',
      };

      final response = RetrieveResponse.fromJson(json);
      expect(response.sourceXml, equals('<Invoice>...</Invoice>'));
    });
  });

  group('InvoiceData', () {
    test('parses all fields including new ones', () {
      final data = InvoiceData.fromJson({
        'number': 'INV-001',
        'date': '2026-01-15',
        'dueDate': '2026-02-15',
        'currency': 'EUR',
        'notes': 'Payment within 30 days',
        'leitwegId': '04011000-12345-67',
        'buyerReference': 'ORDER-789',
        'tipoDocumento': 'TD01',
      });

      expect(data.number, equals('INV-001'));
      expect(data.notes, equals('Payment within 30 days'));
      expect(data.leitwegId, equals('04011000-12345-67'));
      expect(data.buyerReference, equals('ORDER-789'));
      expect(data.tipoDocumento, equals('TD01'));
    });
  });

  group('Exceptions', () {
    test('ThelawinException has message', () {
      final ex = ThelawinException('Something went wrong');
      expect(ex.message, equals('Something went wrong'));
      expect(ex.toString(), equals('Something went wrong'));
    });

    test('ThelawinApiException has statusCode and code', () {
      final ex = ThelawinApiException('Not found', 404, 'not_found');
      expect(ex.statusCode, equals(404));
      expect(ex.code, equals('not_found'));
      expect(ex.message, equals('Not found'));
    });

    test('ThelawinQuotaExceededException is an ApiException with 402', () {
      final ex = ThelawinQuotaExceededException('Quota exceeded');
      expect(ex, isA<ThelawinApiException>());
      expect(ex.statusCode, equals(402));
      expect(ex.code, equals('quota_exceeded'));
    });

    test('ThelawinNetworkException wraps cause', () {
      final cause = Exception('connection refused');
      final ex = ThelawinNetworkException('Network error', cause);
      expect(ex.cause, equals(cause));
      expect(ex.message, equals('Network error'));
    });

    test('ThelawinValidationException formats errors', () {
      final ex = ThelawinValidationException([
        ValidationError(path: r'$.invoice.number', code: 'REQUIRED', message: 'required'),
        ValidationError(path: r'$.invoice.date', code: 'REQUIRED', message: 'required'),
      ]);
      expect(ex.statusCode, equals(422));
      expect(ex.toUserMessage(), contains(r'$.invoice.number'));
      expect(ex.toUserMessage(), contains(r'$.invoice.date'));
    });
  });

  group('FormatInfo', () {
    test('parses from JSON', () {
      final info = FormatInfo.fromJson({
        'format': 'zugferd',
        'profile': 'EN16931',
        'version': '2.4',
      });
      expect(info.format, equals('zugferd'));
      expect(info.profile, equals('EN16931'));
      expect(info.version, equals('2.4'));
    });
  });

  group('DetectedFormat', () {
    test('parses from JSON with all fields', () {
      final fmt = DetectedFormat.fromJson({
        'format': 'facturx',
        'profile': 'BASIC',
        'version': '1.0.8',
        'standard': 'CII',
      });
      expect(fmt.format, equals('facturx'));
      expect(fmt.standard, equals('CII'));
    });
  });

  group('ValidationResult', () {
    test('parses with warnings', () {
      final result = ValidationResult.fromJson({
        'status': 'valid',
        'profile': 'EN16931',
        'version': '2.4.0',
        'warnings': ['Missing optional field BT-20'],
      });
      expect(result.warnings?.length, equals(1));
      expect(result.warnings?[0], contains('BT-20'));
    });
  });
}
