// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Report

import 'types.dart';

class Report {
  final JsonObject _raw;

  const Report(this._raw);

  factory Report.fromJson(JsonObject json) {
    return Report(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
