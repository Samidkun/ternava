// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DashboardResponse

import 'types.dart';

class DashboardResponse {
  final JsonObject _raw;

  const DashboardResponse(this._raw);

  factory DashboardResponse.fromJson(JsonObject json) {
    return DashboardResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
