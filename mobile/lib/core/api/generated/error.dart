// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Error

import 'types.dart';

class Error {
  final JsonObject _raw;

  const Error(this._raw);

  factory Error.fromJson(JsonObject json) {
    return Error(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
