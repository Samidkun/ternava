// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskRun

import 'types.dart';

class TaskRun {
  final JsonObject _raw;

  const TaskRun(this._raw);

  factory TaskRun.fromJson(JsonObject json) {
    return TaskRun(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
