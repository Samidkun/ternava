// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ChecklistValueResponse

import 'types.dart';

class ChecklistValueResponse {
  final JsonObject _raw;

  const ChecklistValueResponse(this._raw);

  factory ChecklistValueResponse.fromJson(JsonObject json) => ChecklistValueResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
