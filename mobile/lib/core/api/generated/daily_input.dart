// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyInput

import 'types.dart';

class DailyInput {
  final JsonObject _raw;

  const DailyInput(this._raw);

  factory DailyInput.fromJson(JsonObject json) => DailyInput(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
