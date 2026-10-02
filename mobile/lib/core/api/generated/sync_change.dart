// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SyncChange

import 'types.dart';

class SyncChange {
  final JsonObject _raw;

  const SyncChange(this._raw);

  factory SyncChange.fromJson(JsonObject json) {
    return SyncChange(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
