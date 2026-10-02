// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ReportRow

import 'types.dart';

class ReportRow {
  final JsonObject _raw;

  const ReportRow(this._raw);

  factory ReportRow.fromJson(JsonObject json) {
    return ReportRow(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
