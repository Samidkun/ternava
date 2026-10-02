// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FlockUpdate

import 'types.dart';

class FlockUpdate {
  final JsonObject _raw;

  const FlockUpdate(this._raw);

  factory FlockUpdate.fromJson(JsonObject json) {
    return FlockUpdate(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
