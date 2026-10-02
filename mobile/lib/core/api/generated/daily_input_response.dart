// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyInputResponse

import 'types.dart';

class DailyInputResponse {
  final JsonObject _raw;

  const DailyInputResponse(this._raw);

  factory DailyInputResponse.fromJson(JsonObject json) {
    return DailyInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
