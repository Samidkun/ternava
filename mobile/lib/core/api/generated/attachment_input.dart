// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: AttachmentInput

import 'types.dart';

class AttachmentInput {
  final JsonObject _raw;

  const AttachmentInput(this._raw);

  factory AttachmentInput.fromJson(JsonObject json) {
    return AttachmentInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
