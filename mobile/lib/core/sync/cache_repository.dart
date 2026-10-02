import 'dart:async';

import '../api/generated/types.dart';
import '../local/partition_store.dart';

class SyncCheckpoint {
  final String? cursor;
  final int scopeVersion;
  final String asOf;

  const SyncCheckpoint({
    required this.cursor,
    required this.scopeVersion,
    required this.asOf,
  });
}

class CacheRepository {
  final PartitionStore store;
  SyncCheckpoint? _checkpoint;
  final Map<String, Map<String, JsonObject>> _acceptedCaches = {};

  CacheRepository({required this.store});

  Future<SyncCheckpoint?> getCheckpoint() async => _checkpoint;

  Future<void> applyPage(JsonObject page) async {
    await store.transaction(() async {
      final changes = (page['changes'] as List<dynamic>?) ?? [];
      for (final rawChange in changes) {
        if (rawChange is Map<String, dynamic>) {
          final resType = rawChange['resource_type'] as String;
          final resId = rawChange['resource_id'] as String;
          final action = rawChange['action'] as String;
          final value = rawChange['value'] as Map<String, dynamic>?;

          final table = _acceptedCaches.putIfAbsent(resType, () => {});
          if (action == 'remove') {
            table.remove(resId);
          } else if (value != null) {
            table[resId] = value;
          }
        }
      }

      _checkpoint = SyncCheckpoint(
        cursor: page['next_cursor'] as String?,
        scopeVersion: (page['scope_version'] as int?) ?? 1,
        asOf: (page['as_of'] as String?) ?? DateTime.now().toIso8601String(),
      );
    });
  }

  Future<void> replaceAcceptedSnapshot(List<JsonObject> pages) async {
    await store.transaction(() async {
      _acceptedCaches.clear();
      for (final page in pages) {
        final changes = (page['changes'] as List<dynamic>?) ?? [];
        for (final rawChange in changes) {
          if (rawChange is Map<String, dynamic>) {
            final resType = rawChange['resource_type'] as String;
            final resId = rawChange['resource_id'] as String;
            final action = rawChange['action'] as String;
            final value = rawChange['value'] as Map<String, dynamic>?;

            final table = _acceptedCaches.putIfAbsent(resType, () => {});
            if (action == 'remove') {
              table.remove(resId);
            } else if (value != null) {
              table[resId] = value;
            }
          }
        }
      }

      if (pages.isNotEmpty) {
        final last = pages.last;
        _checkpoint = SyncCheckpoint(
          cursor: last['next_cursor'] as String?,
          scopeVersion: (last['scope_version'] as int?) ?? 1,
          asOf: (last['as_of'] as String?) ?? DateTime.now().toIso8601String(),
        );
      }
    });
  }

  Future<Set<String>> getAcceptedIds(String resourceType) async {
    return _acceptedCaches[resourceType]?.keys.toSet() ?? {};
  }

  Future<List<JsonObject>> list(String resourceType) async {
    return _acceptedCaches[resourceType]?.values.toList() ?? [];
  }
}
