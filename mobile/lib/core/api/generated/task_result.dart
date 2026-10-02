// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskResult

import 'types.dart';

class TaskResult {
  final JsonObject _raw;

  const TaskResult(this._raw);

  factory TaskResult.fromJson(JsonObject json) {
    return TaskResult(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
