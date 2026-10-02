// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ResetPasswordInput

import 'types.dart';

class ResetPasswordInput {
  final JsonObject _raw;

  const ResetPasswordInput(this._raw);

  factory ResetPasswordInput.fromJson(JsonObject json) => ResetPasswordInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
