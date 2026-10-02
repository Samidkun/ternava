// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: AttachmentResponse

import 'types.dart';

class AttachmentResponse {
  final JsonObject _raw;

  const AttachmentResponse(this._raw);

  factory AttachmentResponse.fromJson(JsonObject json) {
    return AttachmentResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
