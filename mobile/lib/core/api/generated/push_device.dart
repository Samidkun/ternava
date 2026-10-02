// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: PushDevice

import 'types.dart';

class PushDevice {
  final JsonObject _raw;

  const PushDevice(this._raw);

  factory PushDevice.fromJson(JsonObject json) => PushDevice(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
