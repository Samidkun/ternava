// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: FeedTypeInput

import 'types.dart';

class FeedTypeInput {
  final JsonObject _raw;

  const FeedTypeInput(this._raw);

  factory FeedTypeInput.fromJson(JsonObject json) {
    return FeedTypeInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
