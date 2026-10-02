// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedEntryResponse

import 'types.dart';

class FeedEntryResponse {
  final JsonObject _raw;

  const FeedEntryResponse(this._raw);

  factory FeedEntryResponse.fromJson(JsonObject json) {
    return FeedEntryResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
