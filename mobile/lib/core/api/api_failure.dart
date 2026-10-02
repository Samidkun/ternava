import 'generated/types.dart';

class ApiFailure implements Exception {
  final String code;
  final String message;
  final int status;
  final bool retryable;
  final int? currentVersion;
  final int? retryAfter;
  final Map<String, dynamic>? fields;

  const ApiFailure({
    required this.code,
    required this.message,
    required this.status,
    this.retryable = false,
    this.currentVersion,
    this.retryAfter,
    this.fields,
  });

  factory ApiFailure.fromJson(JsonObject json, int status, {int? retryAfter}) {
    final error = json['error'] as Map<String, dynamic>?;
    if (error == null) {
      return ApiFailure(
        code: 'UNKNOWN_ERROR',
        message: 'Terjadi kesalahan sistem yang tidak terduga.',
        status: status,
        retryAfter: retryAfter,
      );
    }

    return ApiFailure(
      code: error['code'] as String? ?? 'ERROR_$status',
      message: error['message'] as String? ?? 'Terjadi kesalahan.',
      status: status,
      retryable: error['retryable'] as bool? ?? (status >= 500),
      currentVersion: error['current_version'] as int?,
      retryAfter: retryAfter,
      fields: error['fields'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() => 'ApiFailure($code, status: $status, message: $message)';
}
