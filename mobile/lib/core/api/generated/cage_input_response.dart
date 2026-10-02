// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageInputResponse

import 'types.dart';

class CageInputResponse {
  final JsonObject _raw;

  const CageInputResponse(this._raw);

  factory CageInputResponse.fromJson(JsonObject json) {
    return CageInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
