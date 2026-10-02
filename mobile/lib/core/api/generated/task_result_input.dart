// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskResultInput

import 'types.dart';

class TaskResultInput {
  final JsonObject _raw;

  const TaskResultInput(this._raw);

  factory TaskResultInput.fromJson(JsonObject json) {
    return TaskResultInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
