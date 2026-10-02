// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ReportResponse

import 'types.dart';

class ReportResponse {
  final JsonObject _raw;

  const ReportResponse(this._raw);

  factory ReportResponse.fromJson(JsonObject json) => ReportResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
