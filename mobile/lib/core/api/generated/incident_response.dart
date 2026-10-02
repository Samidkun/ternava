// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentResponse

import 'types.dart';

class IncidentResponse {
  final JsonObject _raw;

  const IncidentResponse(this._raw);

  factory IncidentResponse.fromJson(JsonObject json) => IncidentResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
