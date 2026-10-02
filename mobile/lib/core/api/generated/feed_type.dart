// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedType

import 'types.dart';

class FeedType {
  final JsonObject _raw;

  const FeedType(this._raw);

  factory FeedType.fromJson(JsonObject json) {
    return FeedType(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
