// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedTypeUpdate

import 'types.dart';

class FeedTypeUpdate {
  final JsonObject _raw;

  const FeedTypeUpdate(this._raw);

  factory FeedTypeUpdate.fromJson(JsonObject json) {
    return FeedTypeUpdate(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
