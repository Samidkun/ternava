// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedEntryInputResponse

import 'types.dart';

class FeedEntryInputResponse {
  final JsonObject _raw;

  const FeedEntryInputResponse(this._raw);

  factory FeedEntryInputResponse.fromJson(JsonObject json) {
    return FeedEntryInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
