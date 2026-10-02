// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskTemplateUpdateResponse

import 'types.dart';

class TaskTemplateUpdateResponse {
  final JsonObject _raw;

  const TaskTemplateUpdateResponse(this._raw);

  factory TaskTemplateUpdateResponse.fromJson(JsonObject json) => TaskTemplateUpdateResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
