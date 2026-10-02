// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ChecklistItem

import 'types.dart';

class ChecklistItem {
  final JsonObject _raw;

  const ChecklistItem(this._raw);

  factory ChecklistItem.fromJson(JsonObject json) {
    return ChecklistItem(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
