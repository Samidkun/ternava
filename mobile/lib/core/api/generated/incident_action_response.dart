// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentActionResponse

import 'types.dart';

class IncidentActionResponse {
  final JsonObject _raw;

  const IncidentActionResponse(this._raw);

  factory IncidentActionResponse.fromJson(JsonObject json) {
    return IncidentActionResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
