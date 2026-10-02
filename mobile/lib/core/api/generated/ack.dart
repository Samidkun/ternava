// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Ack

import 'types.dart';

class Ack {
  final JsonObject _raw;

  const Ack(this._raw);

  factory Ack.fromJson(JsonObject json) => Ack(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
