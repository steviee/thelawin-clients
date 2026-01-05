import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'client.dart';
import 'types.dart';

/// Result of an invoice generation
sealed class InvoiceResult {
  bool get isSuccess;
  bool get isFailure => !isSuccess;
}

/// Successful invoice generation
class InvoiceSuccess extends InvoiceResult {
  final String pdfBase64;
  final String filename;
  final ValidationResult validation;
  final AccountInfo? account;

  InvoiceSuccess({
    required this.pdfBase64,
    required this.filename,
    required this.validation,
    this.account,
  });

  @override
  bool get isSuccess => true;

  /// Save the PDF to a file
  Future<void> savePdf(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(toBytes());
  }

  /// Get the PDF as bytes
  Uint8List toBytes() => base64Decode(pdfBase64);

  /// Get the PDF as a data URL
  String toDataUrl() => 'data:application/pdf;base64,$pdfBase64';
}

/// Failed invoice generation
class InvoiceFailure extends InvoiceResult {
  final List<ValidationError> errors;

  InvoiceFailure(this.errors);

  @override
  bool get isSuccess => false;
}

/// Fluent builder for creating invoices
class InvoiceBuilder {
  final EnvoiceClient _client;
  String? _number;
  String? _date;
  String? _dueDate;
  Party? _seller;
  Party? _buyer;
  final List<LineItem> _items = [];
  PaymentInfo? _payment;
  String _currency = 'EUR';
  String _template = 'minimal';
  String _locale = 'en';
  String? _logoBase64;
  int? _logoWidthMm;
  String? _footerText;
  String? _accentColor;

  InvoiceBuilder(this._client);

  /// Set the invoice number
  InvoiceBuilder number(String value) {
    _number = value;
    return this;
  }

  /// Set the invoice date (YYYY-MM-DD)
  InvoiceBuilder date(String value) {
    _date = value;
    return this;
  }

  /// Set the invoice date from DateTime
  InvoiceBuilder dateTime(DateTime value) {
    _date = value.toIso8601String().split('T')[0];
    return this;
  }

  /// Set the due date
  InvoiceBuilder dueDate(String value) {
    _dueDate = value;
    return this;
  }

  /// Set the seller
  InvoiceBuilder seller(Party party) {
    _seller = party;
    return this;
  }

  /// Set the buyer
  InvoiceBuilder buyer(Party party) {
    _buyer = party;
    return this;
  }

  /// Add a line item
  InvoiceBuilder addItem(LineItem item) {
    _items.add(item);
    return this;
  }

  /// Set multiple items at once
  InvoiceBuilder items(List<LineItem> items) {
    _items
      ..clear()
      ..addAll(items);
    return this;
  }

  /// Set payment info
  InvoiceBuilder payment(PaymentInfo info) {
    _payment = info;
    return this;
  }

  /// Set the currency
  InvoiceBuilder currency(String value) {
    _currency = value;
    return this;
  }

  /// Set the template
  InvoiceBuilder template(String value) {
    _template = value;
    return this;
  }

  /// Set the locale
  InvoiceBuilder locale(String value) {
    _locale = value;
    return this;
  }

  /// Set logo from file
  Future<InvoiceBuilder> logoFile(String path, {int? widthMm}) async {
    final bytes = await File(path).readAsBytes();
    _logoBase64 = base64Encode(bytes);
    _logoWidthMm = widthMm;
    return this;
  }

  /// Set logo from Base64
  InvoiceBuilder logoBase64(String base64, {int? widthMm}) {
    _logoBase64 = base64;
    _logoWidthMm = widthMm;
    return this;
  }

  /// Set footer text
  InvoiceBuilder footerText(String text) {
    _footerText = text;
    return this;
  }

  /// Set accent color
  InvoiceBuilder accentColor(String color) {
    _accentColor = color;
    return this;
  }

  /// Generate the invoice
  Future<InvoiceResult> generate() async {
    final errors = <ValidationError>[];

    if (_number == null) {
      errors.add(ValidationError(path: r'$.invoice.number', code: 'REQUIRED', message: 'Invoice number is required'));
    }
    if (_date == null) {
      errors.add(ValidationError(path: r'$.invoice.date', code: 'REQUIRED', message: 'Invoice date is required'));
    }
    if (_seller == null) {
      errors.add(ValidationError(path: r'$.invoice.seller', code: 'REQUIRED', message: 'Seller information is required'));
    }
    if (_buyer == null) {
      errors.add(ValidationError(path: r'$.invoice.buyer', code: 'REQUIRED', message: 'Buyer information is required'));
    }
    if (_items.isEmpty) {
      errors.add(ValidationError(path: r'$.invoice.items', code: 'REQUIRED', message: 'At least one line item is required'));
    }

    if (errors.isNotEmpty) {
      return InvoiceFailure(errors);
    }

    final hasCustomization = _logoBase64 != null || _footerText != null || _accentColor != null;

    final request = {
      'template': _template,
      'locale': _locale,
      'invoice': {
        'number': _number,
        'date': _date,
        if (_dueDate != null) 'dueDate': _dueDate,
        'seller': _seller!.toJson(),
        'buyer': _buyer!.toJson(),
        'items': _items.map((i) => i.toJson()).toList(),
        if (_payment != null) 'payment': _payment!.toJson(),
        'currency': _currency,
      },
      if (hasCustomization)
        'customization': {
          if (_logoBase64 != null) 'logoBase64': _logoBase64,
          if (_logoWidthMm != null) 'logoWidthMm': _logoWidthMm,
          if (_footerText != null) 'footerText': _footerText,
          if (_accentColor != null) 'accentColor': _accentColor,
        },
    };

    return _client.generateInvoice(request);
  }
}
