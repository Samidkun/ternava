// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ResetPasswordInputResponse

import 'types.dart';

class ResetPasswordInputResponse {
  final JsonObject _raw;

  const ResetPasswordInputResponse(this._raw);

  factory ResetPasswordInputResponse.fromJson(JsonObject json) {
    return ResetPasswordInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
