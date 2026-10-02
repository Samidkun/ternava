// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedEntry

import 'types.dart';

class FeedEntry {
  final JsonObject _raw;

  const FeedEntry(this._raw);

  factory FeedEntry.fromJson(JsonObject json) => FeedEntry(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
