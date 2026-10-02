// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Session

import 'types.dart';

class Session {
  final JsonObject _raw;

  const Session(this._raw);

  factory Session.fromJson(JsonObject json) => Session(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
