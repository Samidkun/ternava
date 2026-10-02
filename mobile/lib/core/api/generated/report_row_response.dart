// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ReportRowResponse

import 'types.dart';

class ReportRowResponse {
  final JsonObject _raw;

  const ReportRowResponse(this._raw);

  factory ReportRowResponse.fromJson(JsonObject json) {
    return ReportRowResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
