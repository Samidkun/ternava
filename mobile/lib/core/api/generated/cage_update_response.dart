// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageUpdateResponse

import 'types.dart';

class CageUpdateResponse {
  final JsonObject _raw;

  const CageUpdateResponse(this._raw);

  factory CageUpdateResponse.fromJson(JsonObject json) {
    return CageUpdateResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
