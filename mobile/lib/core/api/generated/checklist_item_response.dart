// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ChecklistItemResponse

import 'types.dart';

class ChecklistItemResponse {
  final JsonObject _raw;

  const ChecklistItemResponse(this._raw);

  factory ChecklistItemResponse.fromJson(JsonObject json) {
    return ChecklistItemResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
