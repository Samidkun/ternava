// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PopulationChange

import 'types.dart';

class PopulationChange {
  final JsonObject _raw;

  const PopulationChange(this._raw);

  factory PopulationChange.fromJson(JsonObject json) {
    return PopulationChange(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
