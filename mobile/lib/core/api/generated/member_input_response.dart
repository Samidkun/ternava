// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: MemberInputResponse

import 'types.dart';

class MemberInputResponse {
  final JsonObject _raw;

  const MemberInputResponse(this._raw);

  factory MemberInputResponse.fromJson(JsonObject json) => MemberInputResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
