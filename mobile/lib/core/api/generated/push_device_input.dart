// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PushDeviceInput

import 'types.dart';

class PushDeviceInput {
  final JsonObject _raw;

  const PushDeviceInput(this._raw);

  factory PushDeviceInput.fromJson(JsonObject json) => PushDeviceInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
