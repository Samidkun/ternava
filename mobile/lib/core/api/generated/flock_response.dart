// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FlockResponse

import 'types.dart';

class FlockResponse {
  final JsonObject _raw;

  const FlockResponse(this._raw);

  factory FlockResponse.fromJson(JsonObject json) {
    return FlockResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
