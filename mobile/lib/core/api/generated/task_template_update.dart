// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskTemplateUpdate

import 'types.dart';

class TaskTemplateUpdate {
  final JsonObject _raw;

  const TaskTemplateUpdate(this._raw);

  factory TaskTemplateUpdate.fromJson(JsonObject json) => TaskTemplateUpdate(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
