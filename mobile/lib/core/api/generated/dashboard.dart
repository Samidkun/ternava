// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Dashboard

import 'types.dart';

class Dashboard {
  final JsonObject _raw;

  const Dashboard(this._raw);

  factory Dashboard.fromJson(JsonObject json) {
    return Dashboard(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
