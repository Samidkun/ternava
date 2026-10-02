// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Daily

import 'types.dart';

class Daily {
  final JsonObject _raw;

  const Daily(this._raw);

  factory Daily.fromJson(JsonObject json) {
    return Daily(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
