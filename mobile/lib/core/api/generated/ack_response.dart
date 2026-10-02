// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: AckResponse

import 'types.dart';

class AckResponse {
  final JsonObject _raw;

  const AckResponse(this._raw);

  factory AckResponse.fromJson(JsonObject json) {
    return AckResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
