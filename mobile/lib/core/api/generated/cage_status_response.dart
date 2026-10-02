// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageStatusResponse

import 'types.dart';

class CageStatusResponse {
  final JsonObject _raw;

  const CageStatusResponse(this._raw);

  factory CageStatusResponse.fromJson(JsonObject json) {
    return CageStatusResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
