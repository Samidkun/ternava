// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SyncPageResponse

import 'types.dart';

class SyncPageResponse {
  final JsonObject _raw;

  const SyncPageResponse(this._raw);

  factory SyncPageResponse.fromJson(JsonObject json) {
    return SyncPageResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
