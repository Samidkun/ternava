// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Cage

import 'types.dart';

class Cage {
  final JsonObject _raw;

  const Cage(this._raw);

  factory Cage.fromJson(JsonObject json) {
    return Cage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
