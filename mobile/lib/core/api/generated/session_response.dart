// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SessionResponse

import 'types.dart';

class SessionResponse {
  final JsonObject _raw;

  const SessionResponse(this._raw);

  factory SessionResponse.fromJson(JsonObject json) {
    return SessionResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
