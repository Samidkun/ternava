// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: LoginInput

import 'types.dart';

class LoginInput {
  final JsonObject _raw;

  const LoginInput(this._raw);

  factory LoginInput.fromJson(JsonObject json) {
    return LoginInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
