// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskRunPage

import 'types.dart';

class TaskRunPage {
  final JsonObject _raw;

  const TaskRunPage(this._raw);

  factory TaskRunPage.fromJson(JsonObject json) {
    return TaskRunPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
