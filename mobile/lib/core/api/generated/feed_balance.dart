// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedBalance

import 'types.dart';

class FeedBalance {
  final JsonObject _raw;

  const FeedBalance(this._raw);

  factory FeedBalance.fromJson(JsonObject json) {
    return FeedBalance(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
