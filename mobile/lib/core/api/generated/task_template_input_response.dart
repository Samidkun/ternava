// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskTemplateInputResponse

import 'types.dart';

class TaskTemplateInputResponse {
  final JsonObject _raw;

  const TaskTemplateInputResponse(this._raw);

  factory TaskTemplateInputResponse.fromJson(JsonObject json) {
    return TaskTemplateInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
