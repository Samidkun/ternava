// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskTemplate

import 'types.dart';

class TaskTemplate {
  final JsonObject _raw;

  const TaskTemplate(this._raw);

  factory TaskTemplate.fromJson(JsonObject json) => TaskTemplate(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
