// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SyncChangeResponse

import 'types.dart';

class SyncChangeResponse {
  final JsonObject _raw;

  const SyncChangeResponse(this._raw);

  factory SyncChangeResponse.fromJson(JsonObject json) {
    return SyncChangeResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
