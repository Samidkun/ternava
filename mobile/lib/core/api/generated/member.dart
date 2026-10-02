// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: Member

import 'types.dart';

class Member {
  final JsonObject _raw;

  const Member(this._raw);

  factory Member.fromJson(JsonObject json) {
    return Member(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
