// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: MemberUpdateResponse

import 'types.dart';

class MemberUpdateResponse {
  final JsonObject _raw;

  const MemberUpdateResponse(this._raw);

  factory MemberUpdateResponse.fromJson(JsonObject json) => MemberUpdateResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
