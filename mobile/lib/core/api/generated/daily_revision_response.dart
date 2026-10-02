// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyRevisionResponse

import 'types.dart';

class DailyRevisionResponse {
  final JsonObject _raw;

  const DailyRevisionResponse(this._raw);

  factory DailyRevisionResponse.fromJson(JsonObject json) => DailyRevisionResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
