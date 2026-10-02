// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedBalanceResponse

import 'types.dart';

class FeedBalanceResponse {
  final JsonObject _raw;

  const FeedBalanceResponse(this._raw);

  factory FeedBalanceResponse.fromJson(JsonObject json) => FeedBalanceResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
