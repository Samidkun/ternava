// GENERATED CODE - DO NOT MODIFY BY HAND
// Schema: InboxResponse

import 'types.dart';

class InboxResponse {
  final JsonObject _raw;

  const InboxResponse(this._raw);

  factory InboxResponse.fromJson(JsonObject json) => InboxResponse(Map<String, Object?>.from(json));

  JsonObject toJson() => Map<String, Object?>.unmodifiable(_raw);

  Object? operator [](String key) => _raw[key];
}
