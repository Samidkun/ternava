// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Flock

import 'types.dart';

class Flock {
  final JsonObject _raw;

  const Flock(this._raw);

  factory Flock.fromJson(JsonObject json) {
    return Flock(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
