// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: MemberInput

import 'types.dart';

class MemberInput {
  final JsonObject _raw;

  const MemberInput(this._raw);

  factory MemberInput.fromJson(JsonObject json) {
    return MemberInput(Map<String, Object?>.from(json));
  }

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
