// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PushDeviceInputResponse

import 'types.dart';

class PushDeviceInputResponse {
  final JsonObject _raw;

  const PushDeviceInputResponse(this._raw);

  factory PushDeviceInputResponse.fromJson(JsonObject json) => PushDeviceInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
