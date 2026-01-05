import 'dart:convert';
import 'package:http/http.dart' as http;

import 'errors.dart';
import 'invoice.dart';
import 'types.dart';

/// Main client for interacting with the envoice.dev API
class EnvoiceClient {
  final String apiKey;
  final String apiUrl;
  final Duration timeout;
  final http.Client _client;

  /// Create a new EnvoiceClient
  EnvoiceClient(
    this.apiKey, {
    this.apiUrl = 'https://api.envoice.dev',
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client() {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key is required');
    }
  }

  /// Create a new invoice builder
  InvoiceBuilder invoice() => InvoiceBuilder(this);

  /// Generate an invoice directly
  Future<InvoiceResult> generateInvoice(Map<String, dynamic> request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$apiUrl/v1/generate'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey,
            },
            body: jsonEncode(request),
          )
          .timeout(timeout);

      return _handleGenerateResponse(response);
    } on http.ClientException catch (e) {
      throw EnvoiceNetworkException('Network error: ${e.message}', e);
    } catch (e) {
      if (e is EnvoiceException) rethrow;
      throw EnvoiceNetworkException('Unknown error: $e', e);
    }
  }

  InvoiceResult _handleGenerateResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    switch (response.statusCode) {
      case 200:
        return InvoiceSuccess(
          pdfBase64: body['pdf_base64'] as String,
          filename: body['filename'] as String,
          validation: ValidationResult.fromJson(body['validation'] as Map<String, dynamic>),
          account: body['account'] != null ? AccountInfo.fromJson(body['account'] as Map<String, dynamic>) : null,
        );

      case 402:
        throw EnvoiceQuotaExceededException(body['message'] as String? ?? 'Quota exceeded');

      case 422:
        final details = body['details'] as List?;
        if (details != null) {
          return InvoiceFailure(
            details.map((e) => ValidationError.fromJson(e as Map<String, dynamic>)).toList(),
          );
        }
        throw EnvoiceApiException(
          body['message'] as String? ?? body['error'] as String,
          422,
          body['error'] as String?,
        );

      default:
        throw EnvoiceApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
    }
  }

  /// Validate an existing PDF
  Future<Map<String, dynamic>> validate(String pdfBase64) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$apiUrl/v1/validate'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey,
            },
            body: jsonEncode({'pdf_base64': pdfBase64}),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw EnvoiceApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on http.ClientException catch (e) {
      throw EnvoiceNetworkException('Network error: ${e.message}', e);
    }
  }

  /// Get account information
  Future<AccountInfo> getAccount() async {
    try {
      final response = await _client
          .get(
            Uri.parse('$apiUrl/v1/account'),
            headers: {'X-API-Key': apiKey},
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw EnvoiceApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
      }

      return AccountInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on http.ClientException catch (e) {
      throw EnvoiceNetworkException('Network error: ${e.message}', e);
    }
  }

  /// Close the client
  void close() => _client.close();
}
