// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FarmResponse

import 'types.dart';

class FarmResponse {
  final JsonObject _raw;

  const FarmResponse(this._raw);

  factory FarmResponse.fromJson(JsonObject json) {
    return FarmResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
