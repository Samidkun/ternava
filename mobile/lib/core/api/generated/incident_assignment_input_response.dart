// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentAssignmentInputResponse

import 'types.dart';

class IncidentAssignmentInputResponse {
  final JsonObject _raw;

  const IncidentAssignmentInputResponse(this._raw);

  factory IncidentAssignmentInputResponse.fromJson(JsonObject json) => IncidentAssignmentInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
