// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentAssignmentInput

import 'types.dart';

class IncidentAssignmentInput {
  final JsonObject _raw;

  const IncidentAssignmentInput(this._raw);

  factory IncidentAssignmentInput.fromJson(JsonObject json) => IncidentAssignmentInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
