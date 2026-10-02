// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: CageUpdate

import 'types.dart';

class CageUpdate {
  final JsonObject _raw;

  const CageUpdate(this._raw);

  factory CageUpdate.fromJson(JsonObject json) {
    return CageUpdate(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
