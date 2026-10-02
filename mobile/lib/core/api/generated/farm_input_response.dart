// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FarmInputResponse

import 'types.dart';

class FarmInputResponse {
  final JsonObject _raw;

  const FarmInputResponse(this._raw);

  factory FarmInputResponse.fromJson(JsonObject json) => FarmInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
