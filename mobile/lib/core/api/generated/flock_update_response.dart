// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FlockUpdateResponse

import 'types.dart';

class FlockUpdateResponse {
  final JsonObject _raw;

  const FlockUpdateResponse(this._raw);

  factory FlockUpdateResponse.fromJson(JsonObject json) {
    return FlockUpdateResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
