// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: AttachmentInputResponse

import 'types.dart';

class AttachmentInputResponse {
  final JsonObject _raw;

  const AttachmentInputResponse(this._raw);

  factory AttachmentInputResponse.fromJson(JsonObject json) {
    return AttachmentInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
