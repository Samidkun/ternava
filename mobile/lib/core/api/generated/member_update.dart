// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: MemberUpdate

import 'types.dart';

class MemberUpdate {
  final JsonObject _raw;

  const MemberUpdate(this._raw);

  factory MemberUpdate.fromJson(JsonObject json) => MemberUpdate(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
