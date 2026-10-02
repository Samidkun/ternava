// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FarmInput

import 'types.dart';

class FarmInput {
  final JsonObject _raw;

  const FarmInput(this._raw);

  factory FarmInput.fromJson(JsonObject json) => FarmInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
