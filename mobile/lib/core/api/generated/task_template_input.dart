// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskTemplateInput

import 'types.dart';

class TaskTemplateInput {
  final JsonObject _raw;

  const TaskTemplateInput(this._raw);

  factory TaskTemplateInput.fromJson(JsonObject json) => TaskTemplateInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
