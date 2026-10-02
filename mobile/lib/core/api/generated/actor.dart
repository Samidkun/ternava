// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Actor

import 'types.dart';

class Actor {
  final JsonObject _raw;

  const Actor(this._raw);

  factory Actor.fromJson(JsonObject json) {
    return Actor(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
