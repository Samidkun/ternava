// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Attachment

import 'types.dart';

class Attachment {
  final JsonObject _raw;

  const Attachment(this._raw);

  factory Attachment.fromJson(JsonObject json) {
    return Attachment(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
