// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyRevisionInput

import 'types.dart';

class DailyRevisionInput {
  final JsonObject _raw;

  const DailyRevisionInput(this._raw);

  factory DailyRevisionInput.fromJson(JsonObject json) {
    return DailyRevisionInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
