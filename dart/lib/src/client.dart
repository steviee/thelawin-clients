import 'dart:convert';
import 'package:http/http.dart' as http;

import 'errors.dart';
import 'invoice.dart';
import 'types.dart';

/// Main client for interacting with the thelawin.dev API
class ThelawinClient {
  final String apiKey;
  final String apiUrl;
  final Duration timeout;
  final http.Client _client;

  /// Create a new ThelawinClient
  ThelawinClient(
    this.apiKey, {
    this.apiUrl = 'https://api.thelawin.dev',
    this.timeout = const Duration(seconds: 30),
    http.Client? client,
  }) : _client = client ?? http.Client() {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key is required');
    }
  }

  /// Create a new invoice builder
  InvoiceBuilder invoice() => InvoiceBuilder(this);

  /// Generate an invoice directly from a request map
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
      throw ThelawinNetworkException('Network error: ${e.message}', e);
    } catch (e) {
      if (e is ThelawinException) rethrow;
      throw ThelawinNetworkException('Unknown error: $e', e);
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
        throw ThelawinQuotaExceededException(body['message'] as String? ?? 'Quota exceeded');

      case 422:
        final details = body['details'] as List?;
        if (details != null) {
          return InvoiceFailure(
            details.map((e) => ValidationError.fromJson(e as Map<String, dynamic>)).toList(),
          );
        }
        throw ThelawinApiException(
          body['message'] as String? ?? body['error'] as String,
          422,
          body['error'] as String?,
        );

      default:
        throw ThelawinApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
    }
  }

  /// Validate invoice JSON without generating a PDF
  Future<Map<String, dynamic>> validate(Map<String, dynamic> request) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$apiUrl/v1/validate'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey,
            },
            body: jsonEncode(request),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw ThelawinApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
      }

      return jsonDecode(response.body) as Map<String, dynamic>;
    } on http.ClientException catch (e) {
      throw ThelawinNetworkException('Network error: ${e.message}', e);
    }
  }

  /// Extract invoice data from a PDF or XML document
  ///
  /// [dataBase64] - Base64-encoded PDF or XML content
  /// [contentType] - MIME type hint (e.g. "application/pdf", "text/xml")
  /// [includeSourceXml] - Whether to include the raw source XML in the response
  Future<RetrieveResponse> retrieve(
    String dataBase64, {
    String? contentType,
    bool includeSourceXml = false,
  }) async {
    try {
      final request = <String, dynamic>{
        'data_base64': dataBase64,
        if (contentType != null) 'content_type': contentType,
        if (includeSourceXml) 'include_source_xml': true,
      };

      final response = await _client
          .post(
            Uri.parse('$apiUrl/v1/retrieve'),
            headers: {
              'Content-Type': 'application/json',
              'X-API-Key': apiKey,
            },
            body: jsonEncode(request),
          )
          .timeout(timeout);

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        throw ThelawinApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
      }

      return RetrieveResponse.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on http.ClientException catch (e) {
      throw ThelawinNetworkException('Network error: ${e.message}', e);
    } catch (e) {
      if (e is ThelawinException) rethrow;
      throw ThelawinNetworkException('Unknown error: $e', e);
    }
  }

  /// Get account information (plan, remaining credits)
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
        throw ThelawinApiException(
          body['message'] as String? ?? 'HTTP ${response.statusCode}',
          response.statusCode,
          body['error'] as String?,
        );
      }

      return AccountInfo.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on http.ClientException catch (e) {
      throw ThelawinNetworkException('Network error: ${e.message}', e);
    }
  }

  /// Close the HTTP client and release resources
  void close() => _client.close();
}
