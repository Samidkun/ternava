// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedEntryInput

import 'types.dart';

class FeedEntryInput {
  final JsonObject _raw;

  const FeedEntryInput(this._raw);

  factory FeedEntryInput.fromJson(JsonObject json) {
    return FeedEntryInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
