// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskTemplateResponse

import 'types.dart';

class TaskTemplateResponse {
  final JsonObject _raw;

  const TaskTemplateResponse(this._raw);

  factory TaskTemplateResponse.fromJson(JsonObject json) => TaskTemplateResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
