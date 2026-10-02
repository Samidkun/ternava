// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentActionInput

import 'types.dart';

class IncidentActionInput {
  final JsonObject _raw;

  const IncidentActionInput(this._raw);

  factory IncidentActionInput.fromJson(JsonObject json) => IncidentActionInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
