// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SessionInfoResponse

import 'types.dart';

class SessionInfoResponse {
  final JsonObject _raw;

  const SessionInfoResponse(this._raw);

  factory SessionInfoResponse.fromJson(JsonObject json) => SessionInfoResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
