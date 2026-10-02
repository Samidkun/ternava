// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedBalancePage

import 'types.dart';

class FeedBalancePage {
  final JsonObject _raw;

  const FeedBalancePage(this._raw);

  factory FeedBalancePage.fromJson(JsonObject json) {
    return FeedBalancePage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
