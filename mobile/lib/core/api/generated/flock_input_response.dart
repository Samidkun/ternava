// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FlockInputResponse

import 'types.dart';

class FlockInputResponse {
  final JsonObject _raw;

  const FlockInputResponse(this._raw);

  factory FlockInputResponse.fromJson(JsonObject json) => FlockInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
