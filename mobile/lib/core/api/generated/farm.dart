// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Farm

import 'types.dart';

class Farm {
  final JsonObject _raw;

  const Farm(this._raw);

  factory Farm.fromJson(JsonObject json) => Farm(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
