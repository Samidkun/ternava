// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentPage

import 'types.dart';

class IncidentPage {
  final JsonObject _raw;

  const IncidentPage(this._raw);

  factory IncidentPage.fromJson(JsonObject json) {
    return IncidentPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
