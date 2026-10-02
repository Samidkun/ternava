// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: AttachmentPage

import 'types.dart';

class AttachmentPage {
  final JsonObject _raw;

  const AttachmentPage(this._raw);

  factory AttachmentPage.fromJson(JsonObject json) => AttachmentPage(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
