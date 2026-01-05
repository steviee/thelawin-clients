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

  Party({
    required this.name,
    this.street,
    this.city,
    this.postalCode,
    this.country,
    this.vatId,
    this.email,
    this.phone,
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
      };
}

/// Line item in an invoice
class LineItem {
  final String description;
  final double quantity;
  final String unit;
  final double unitPrice;
  final double vatRate;

  LineItem({
    required this.description,
    required this.quantity,
    this.unit = 'C62',
    required this.unitPrice,
    this.vatRate = 19.0,
  });

  Map<String, dynamic> toJson() => {
        'description': description,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'vatRate': vatRate,
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

/// Validation result
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

/// Validation error
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
