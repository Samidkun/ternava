// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedTypeUpdateResponse

import 'types.dart';

class FeedTypeUpdateResponse {
  final JsonObject _raw;

  const FeedTypeUpdateResponse(this._raw);

  factory FeedTypeUpdateResponse.fromJson(JsonObject json) {
    return FeedTypeUpdateResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
