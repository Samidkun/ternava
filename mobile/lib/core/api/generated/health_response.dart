// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: HealthResponse

import 'types.dart';

class HealthResponse {
  final JsonObject _raw;

  const HealthResponse(this._raw);

  factory HealthResponse.fromJson(JsonObject json) {
    return HealthResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
