// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: SyncPage

import 'types.dart';

class SyncPage {
  final JsonObject _raw;

  const SyncPage(this._raw);

  factory SyncPage.fromJson(JsonObject json) {
    return SyncPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
