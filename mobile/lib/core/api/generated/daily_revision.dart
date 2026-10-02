// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: DailyRevision

import 'types.dart';

class DailyRevision {
  final JsonObject _raw;

  const DailyRevision(this._raw);

  factory DailyRevision.fromJson(JsonObject json) {
    return DailyRevision(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
