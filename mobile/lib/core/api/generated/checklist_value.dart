// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ChecklistValue

import 'types.dart';

class ChecklistValue {
  final JsonObject _raw;

  const ChecklistValue(this._raw);

  factory ChecklistValue.fromJson(JsonObject json) => ChecklistValue(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
