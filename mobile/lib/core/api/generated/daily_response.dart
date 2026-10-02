// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyResponse

import 'types.dart';

class DailyResponse {
  final JsonObject _raw;

  const DailyResponse(this._raw);

  factory DailyResponse.fromJson(JsonObject json) => DailyResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
