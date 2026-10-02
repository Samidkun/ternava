// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageResponse

import 'types.dart';

class CageResponse {
  final JsonObject _raw;

  const CageResponse(this._raw);

  factory CageResponse.fromJson(JsonObject json) {
    return CageResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
