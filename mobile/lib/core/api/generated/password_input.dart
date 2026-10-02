// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PasswordInput

import 'types.dart';

class PasswordInput {
  final JsonObject _raw;

  const PasswordInput(this._raw);

  factory PasswordInput.fromJson(JsonObject json) {
    return PasswordInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
