// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: TaskResultInputResponse

import 'types.dart';

class TaskResultInputResponse {
  final JsonObject _raw;

  const TaskResultInputResponse(this._raw);

  factory TaskResultInputResponse.fromJson(JsonObject json) => TaskResultInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
