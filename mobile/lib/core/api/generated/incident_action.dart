// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: IncidentAction

import 'types.dart';

class IncidentAction {
  final JsonObject _raw;

  const IncidentAction(this._raw);

  factory IncidentAction.fromJson(JsonObject json) => IncidentAction(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
