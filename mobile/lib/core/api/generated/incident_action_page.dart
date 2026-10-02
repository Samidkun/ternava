// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentActionPage

import 'types.dart';

class IncidentActionPage {
  final JsonObject _raw;

  const IncidentActionPage(this._raw);

  factory IncidentActionPage.fromJson(JsonObject json) {
    return IncidentActionPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
