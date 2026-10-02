// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PopulationChangeResponse

import 'types.dart';

class PopulationChangeResponse {
  final JsonObject _raw;

  const PopulationChangeResponse(this._raw);

  factory PopulationChangeResponse.fromJson(JsonObject json) {
    return PopulationChangeResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
