// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Inbox

import 'types.dart';

class Inbox {
  final JsonObject _raw;

  const Inbox(this._raw);

  factory Inbox.fromJson(JsonObject json) => Inbox(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
