// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageInput

import 'types.dart';

class CageInput {
  final JsonObject _raw;

  const CageInput(this._raw);

  factory CageInput.fromJson(JsonObject json) {
    return CageInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
