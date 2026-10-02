// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Health

import 'types.dart';

class Health {
  final JsonObject _raw;

  const Health(this._raw);

  factory Health.fromJson(JsonObject json) => Health(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
