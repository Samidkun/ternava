// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: MemberPage

import 'types.dart';

class MemberPage {
  final JsonObject _raw;

  const MemberPage(this._raw);

  factory MemberPage.fromJson(JsonObject json) {
    return MemberPage(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
