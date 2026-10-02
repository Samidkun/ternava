// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyRevisionInputResponse

import 'types.dart';

class DailyRevisionInputResponse {
  final JsonObject _raw;

  const DailyRevisionInputResponse(this._raw);

  factory DailyRevisionInputResponse.fromJson(JsonObject json) {
    return DailyRevisionInputResponse(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
