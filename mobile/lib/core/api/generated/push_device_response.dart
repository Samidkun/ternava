// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PushDeviceResponse

import 'types.dart';

class PushDeviceResponse {
  final JsonObject _raw;

  const PushDeviceResponse(this._raw);

  factory PushDeviceResponse.fromJson(JsonObject json) {
    return PushDeviceResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
