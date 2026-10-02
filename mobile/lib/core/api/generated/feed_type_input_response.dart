// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedTypeInputResponse

import 'types.dart';

class FeedTypeInputResponse {
  final JsonObject _raw;

  const FeedTypeInputResponse(this._raw);

  factory FeedTypeInputResponse.fromJson(JsonObject json) => FeedTypeInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
