// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentInputResponse

import 'types.dart';

class IncidentInputResponse {
  final JsonObject _raw;

  const IncidentInputResponse(this._raw);

  factory IncidentInputResponse.fromJson(JsonObject json) => IncidentInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
