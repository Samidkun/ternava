// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentActionInputResponse

import 'types.dart';

class IncidentActionInputResponse {
  final JsonObject _raw;

  const IncidentActionInputResponse(this._raw);

  factory IncidentActionInputResponse.fromJson(JsonObject json) {
    return IncidentActionInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
