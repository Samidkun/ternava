// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageStatus

import 'types.dart';

class CageStatus {
  final JsonObject _raw;

  const CageStatus(this._raw);

  factory CageStatus.fromJson(JsonObject json) {
    return CageStatus(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
