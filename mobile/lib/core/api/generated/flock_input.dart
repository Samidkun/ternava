// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FlockInput

import 'types.dart';

class FlockInput {
  final JsonObject _raw;

  const FlockInput(this._raw);

  factory FlockInput.fromJson(JsonObject json) {
    return FlockInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
