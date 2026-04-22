/// Supported invoice output formats
enum InvoiceFormat {
  auto,
  zugferd,
  facturx,
  xrechnung,
  ubl,
  cii,
  peppol,
  fatturapa,
  pdf;

  String toJson() => name;
}

/// ZUGFeRD/Factur-X conformance profile
enum InvoiceProfile {
  minimum,
  basicWl,
  basic,
  en16931,
  extended;

  String toJson() => switch (this) {
        InvoiceProfile.minimum => 'MINIMUM',
        InvoiceProfile.basicWl => 'BASIC_WL',
        InvoiceProfile.basic => 'BASIC',
        InvoiceProfile.en16931 => 'EN16931',
        InvoiceProfile.extended => 'EXTENDED',
      };
}

/// Party (seller or buyer) information
class Party {
  final String name;
  final String? street;
  final String? city;
  final String? postalCode;
  final String? country;
  final String? vatId;
  final String? email;
  final String? phone;

  /// Peppol endpoint ID (e.g. "0088:1234567890123")
  final String? endpointId;

  /// Peppol endpoint scheme (e.g. "0088")
  final String? endpointScheme;

  /// Italian fiscal code (Codice Fiscale) for FatturaPA
  final String? codiceFiscale;

  /// Italian SDI destination code for FatturaPA
  final String? codiceDestinatario;

  /// Italian PEC email for FatturaPA
  final String? pecDestinatario;

  Party({
    required this.name,
    this.street,
    this.city,
    this.postalCode,
    this.country,
    this.vatId,
    this.email,
    this.phone,
    this.endpointId,
    this.endpointScheme,
    this.codiceFiscale,
    this.codiceDestinatario,
    this.pecDestinatario,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        if (street != null) 'street': street,
        if (city != null) 'city': city,
        if (postalCode != null) 'postalCode': postalCode,
        if (country != null) 'country': country,
        if (vatId != null) 'vatId': vatId,
        if (email != null) 'email': email,
        if (phone != null) 'phone': phone,
        if (endpointId != null) 'endpointId': endpointId,
        if (endpointScheme != null) 'endpointScheme': endpointScheme,
        if (codiceFiscale != null) 'codiceFiscale': codiceFiscale,
        if (codiceDestinatario != null) 'codiceDestinatario': codiceDestinatario,
        if (pecDestinatario != null) 'pecDestinatario': pecDestinatario,
      };
}

/// Line item in an invoice
class LineItem {
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double vatRate;

  /// Italian tax nature code for zero-rate VAT (e.g. "N1", "N2.2")
  final String? natura;

  LineItem({
    required this.description,
    required this.quantity,
    this.unit = 'C62',
    required this.unitPrice,
    this.vatRate = 19.0,
    this.natura,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'vatRate': vatRate,
        if (natura != null) 'natura': natura,
      };
}

/// Payment information
class PaymentInfo {
  final String? iban;
  final String? bic;
  final String? terms;
  final String? reference;

  PaymentInfo({this.iban, this.bic, this.terms, this.reference});

  Map<String, dynamic> toJson() => {
        if (iban != null) 'iban': iban,
        if (bic != null) 'bic': bic,
        if (terms != null) 'terms': terms,
        if (reference != null) 'reference': reference,
      };
}

/// Validation result from a generate response
class ValidationResult {
  final String status;
  final String profile;
  final String version;
  final List<String>? warnings;

  ValidationResult({
    required this.status,
    required this.profile,
    required this.version,
    this.warnings,
  });

  factory ValidationResult.fromJson(Map<String, dynamic> json) => ValidationResult(
        status: json['status'] as String,
        profile: json['profile'] as String,
        version: json['version'] as String,
        warnings: (json['warnings'] as List?)?.cast<String>(),
      );
}

/// Account info
class AccountInfo {
  final int remaining;
  final String plan;
  final int? overageCount;
  final int? overageAllowed;
  final String? warning;

  AccountInfo({
    required this.remaining,
    required this.plan,
    this.overageCount,
    this.overageAllowed,
    this.warning,
  });

  factory AccountInfo.fromJson(Map<String, dynamic> json) => AccountInfo(
        remaining: json['remaining'] as int,
        plan: json['plan'] as String,
        overageCount: json['overageCount'] as int?,
        overageAllowed: json['overageAllowed'] as int?,
        warning: json['warning'] as String?,
      );
}

/// Validation error detail
class ValidationError {
  final String path;
  final String code;
  final String message;
  final String? severity;

  ValidationError({
    required this.path,
    required this.code,
    required this.message,
    this.severity,
  });

  factory ValidationError.fromJson(Map<String, dynamic> json) => ValidationError(
        path: json['path'] as String,
        code: json['code'] as String,
        message: json['message'] as String,
        severity: json['severity'] as String?,
      );
}

/// Information about the detected format of a retrieved invoice
class FormatInfo {
  final String format;
  final String? profile;
  final String? version;

  FormatInfo({
    required this.format,
    this.profile,
    this.version,
  });

  factory FormatInfo.fromJson(Map<String, dynamic> json) => FormatInfo(
        format: json['format'] as String,
        profile: json['profile'] as String?,
        version: json['version'] as String?,
      );
}

/// Detected format from a retrieve response
class DetectedFormat {
  final String format;
  final String? profile;
  final String? version;
  final String? standard;

  DetectedFormat({
    required this.format,
    this.profile,
    this.version,
    this.standard,
  });

  factory DetectedFormat.fromJson(Map<String, dynamic> json) => DetectedFormat(
        format: json['format'] as String,
        profile: json['profile'] as String?,
        version: json['version'] as String?,
        standard: json['standard'] as String?,
      );
}

/// Error detail from a retrieve response
class RetrieveError {
  final String code;
  final String message;

  RetrieveError({
    required this.code,
    required this.message,
  });

  factory RetrieveError.fromJson(Map<String, dynamic> json) => RetrieveError(
        code: json['code'] as String,
        message: json['message'] as String,
      );
}

/// Response from the /v1/retrieve endpoint
class RetrieveResponse {
  final Map<String, dynamic>? invoice;
  final DetectedFormat? detectedFormat;
  final String? sourceXml;
  final List<RetrieveError>? errors;
  final AccountInfo? account;

  RetrieveResponse({
    this.invoice,
    this.detectedFormat,
    this.sourceXml,
    this.errors,
    this.account,
  });

  bool get isSuccess => invoice != null && (errors == null || errors!.isEmpty);
  bool get isFailure => !isSuccess;

  factory RetrieveResponse.fromJson(Map<String, dynamic> json) => RetrieveResponse(
        invoice: json['invoice'] as Map<String, dynamic>?,
        detectedFormat: json['detectedFormat'] != null
            ? DetectedFormat.fromJson(json['detectedFormat'] as Map<String, dynamic>)
            : null,
        sourceXml: json['sourceXml'] as String?,
        errors: (json['errors'] as List?)
            ?.map((e) => RetrieveError.fromJson(e as Map<String, dynamic>))
            .toList(),
        account: json['account'] != null
            ? AccountInfo.fromJson(json['account'] as Map<String, dynamic>)
            : null,
      );
}

/// Invoice data extracted by /v1/retrieve (typed wrapper)
class InvoiceData {
  final String? number;
  final String? date;
  final String? dueDate;
  final Map<String, dynamic>? seller;
  final Map<String, dynamic>? buyer;
  final List<Map<String, dynamic>>? items;
  final Map<String, dynamic>? payment;
  final String? currency;
  final String? notes;
  final String? leitwegId;
  final String? buyerReference;
  final String? tipoDocumento;

  InvoiceData({
    this.number,
    this.date,
    this.dueDate,
    this.seller,
    this.buyer,
    this.items,
    this.payment,
    this.currency,
    this.notes,
    this.leitwegId,
    this.buyerReference,
    this.tipoDocumento,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) => InvoiceData(
        number: json['number'] as String?,
        date: json['date'] as String?,
        dueDate: json['dueDate'] as String?,
        seller: json['seller'] as Map<String, dynamic>?,
        buyer: json['buyer'] as Map<String, dynamic>?,
        items: (json['items'] as List?)
            ?.map((e) => e as Map<String, dynamic>)
            .toList(),
        payment: json['payment'] as Map<String, dynamic>?,
        currency: json['currency'] as String?,
        notes: json['notes'] as String?,
        leitwegId: json['leitwegId'] as String?,
        buyerReference: json['buyerReference'] as String?,
        tipoDocumento: json['tipoDocumento'] as String?,
      );
}
