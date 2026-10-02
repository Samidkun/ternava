// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: LoginInputResponse

import 'types.dart';

class LoginInputResponse {
  final JsonObject _raw;

  const LoginInputResponse(this._raw);

  factory LoginInputResponse.fromJson(JsonObject json) => LoginInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
