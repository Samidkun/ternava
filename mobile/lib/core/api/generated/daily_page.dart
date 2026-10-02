// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyPage

import 'types.dart';

class DailyPage {
  final JsonObject _raw;

  const DailyPage(this._raw);

  factory DailyPage.fromJson(JsonObject json) {
    return DailyPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
