// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedEntryPage

import 'types.dart';

class FeedEntryPage {
  final JsonObject _raw;

  const FeedEntryPage(this._raw);

  factory FeedEntryPage.fromJson(JsonObject json) {
    return FeedEntryPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
