// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedTypeResponse

import 'types.dart';

class FeedTypeResponse {
  final JsonObject _raw;

  const FeedTypeResponse(this._raw);

  factory FeedTypeResponse.fromJson(JsonObject json) => FeedTypeResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
