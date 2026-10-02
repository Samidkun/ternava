// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentInput

import 'types.dart';

class IncidentInput {
  final JsonObject _raw;

  const IncidentInput(this._raw);

  factory IncidentInput.fromJson(JsonObject json) {
    return IncidentInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
