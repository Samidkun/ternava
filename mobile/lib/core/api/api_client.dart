import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'api_failure.dart';
import 'generated/types.dart';

class ApiClient {
  final String baseUrl;
  final HttpClient _httpClient;
  String? _authToken;

  ApiClient({
    required this.baseUrl,
    HttpClient? httpClient,
  }) : _httpClient = httpClient ?? HttpClient();

  void setAuthToken(String? token) {
    _authToken = token;
  }

  static const Map<String, ({String method, String path})> _operations = {
    'login': (method: 'POST', path: '/api/v1/session'),
    'session': (method: 'GET', path: '/api/v1/session'),
    'changePassword': (method: 'POST', path: '/api/v1/account/password'),
    'logout': (method: 'DELETE', path: '/api/v1/session'),
    'getFarm': (method: 'GET', path: '/api/v1/farm'),
    'updateFarm': (method: 'PATCH', path: '/api/v1/farm'),
    'listCage': (method: 'GET', path: '/api/v1/cages'),
    'createCage': (method: 'POST', path: '/api/v1/cages'),
    'getCage': (method: 'GET', path: '/api/v1/cages/{id}'),
    'updateCage': (method: 'PATCH', path: '/api/v1/cages/{id}'),
    'listFlock': (method: 'GET', path: '/api/v1/flocks'),
    'createFlock': (method: 'POST', path: '/api/v1/flocks'),
    'getFlock': (method: 'GET', path: '/api/v1/flocks/{id}'),
    'updateFlock': (method: 'PATCH', path: '/api/v1/flocks/{id}'),
    'listMember': (method: 'GET', path: '/api/v1/members'),
    'createMember': (method: 'POST', path: '/api/v1/members'),
    'getMember': (method: 'GET', path: '/api/v1/members/{id}'),
    'updateMember': (method: 'PATCH', path: '/api/v1/members/{id}'),
    'listFeedType': (method: 'GET', path: '/api/v1/feed-types'),
    'createFeedType': (method: 'POST', path: '/api/v1/feed-types'),
    'getFeedType': (method: 'GET', path: '/api/v1/feed-types/{id}'),
    'updateFeedType': (method: 'PATCH', path: '/api/v1/feed-types/{id}'),
    'listBalances': (method: 'GET', path: '/api/v1/feed-balances'),
    'listEntries': (method: 'GET', path: '/api/v1/feed-entries'),
    'createEntry': (method: 'POST', path: '/api/v1/feed-entries'),
    'listDaily': (method: 'GET', path: '/api/v1/daily-records'),
    'createDaily': (method: 'POST', path: '/api/v1/daily-records'),
    'getDaily': (method: 'GET', path: '/api/v1/daily-records/{id}'),
    'listDailyRevisions': (method: 'GET', path: '/api/v1/daily-records/{id}/revisions'),
    'reviseDaily': (method: 'POST', path: '/api/v1/daily-records/{id}/revisions'),
    'bootstrapSync': (method: 'GET', path: '/api/v1/sync/bootstrap'),
    'pullChanges': (method: 'GET', path: '/api/v1/sync/changes'),
  };

  Future<JsonObject> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    JsonObject? body,
    String? idempotencyKey,
  }) async {
    final op = _operations[operationId];
    if (op == null) {
      throw ArgumentError('Operasi tidak dikenali: $operationId');
    }

    var resolvedPath = op.path;
    if (pathParams != null) {
      for (final entry in pathParams.entries) {
        resolvedPath = resolvedPath.replaceAll('{${entry.key}}', entry.value);
      }
    }

    var uri = Uri.parse('$baseUrl$resolvedPath');
    if (queryParams != null && queryParams.isNotEmpty) {
      uri = uri.replace(queryParameters: queryParams);
    }

    try {
      final request = await _httpClient
          .openUrl(op.method, uri)
          .timeout(const Duration(seconds: 20));

      request.headers.set('Accept', 'application/json');
      request.headers.set('Content-Type', 'application/json');

      if (_authToken != null) {
        request.headers.set('Authorization', 'Bearer $_authToken');
      }

      if (idempotencyKey != null) {
        request.headers.set('Idempotency-Key', idempotencyKey);
      }

      if (body != null) {
        request.write(jsonEncode(body));
      }

      final response = await request.close().timeout(const Duration(seconds: 20));
      final responseBody = await response.transform(utf8.decoder).join();

      final statusCode = response.statusCode;

      if (statusCode == 204 || responseBody.isEmpty) {
        return <String, Object?>{};
      }

      final dynamic decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) {
        throw ApiFailure(
          code: 'INVALID_RESPONSE',
          message: 'Format respon server tidak valid.',
          status: statusCode,
        );
      }

      if (statusCode >= 400) {
        final retryAfterHeader = response.headers.value('Retry-After');
        final retryAfter = retryAfterHeader != null ? int.tryParse(retryAfterHeader) : null;
        throw ApiFailure.fromJson(decoded, statusCode, retryAfter: retryAfter);
      }

      return decoded;
    } on SocketException catch (e) {
      throw ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server: ${e.message}',
        status: 0,
        retryable: true,
      );
    } on TimeoutException {
      throw const ApiFailure(
        code: 'TIMEOUT',
        message: 'Permintaan melebihi batas waktu (20 detik).',
        status: 408,
        retryable: true,
      );
    }
  }
}
