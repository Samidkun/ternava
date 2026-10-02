// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Incident

import 'types.dart';

class Incident {
  final JsonObject _raw;

  const Incident(this._raw);

  factory Incident.fromJson(JsonObject json) {
    return Incident(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
