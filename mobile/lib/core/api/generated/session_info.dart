// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SessionInfo

import 'types.dart';

class SessionInfo {
  final JsonObject _raw;

  const SessionInfo(this._raw);

  factory SessionInfo.fromJson(JsonObject json) => SessionInfo(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
