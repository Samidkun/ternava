// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskRunResponse

import 'types.dart';

class TaskRunResponse {
  final JsonObject _raw;

  const TaskRunResponse(this._raw);

  factory TaskRunResponse.fromJson(JsonObject json) => TaskRunResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
