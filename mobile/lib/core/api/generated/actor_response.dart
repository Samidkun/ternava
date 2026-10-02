// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: ActorResponse

import 'types.dart';

class ActorResponse {
  final JsonObject _raw;

  const ActorResponse(this._raw);

  factory ActorResponse.fromJson(JsonObject json) => ActorResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
