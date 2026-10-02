import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/bootstrap_coordinator.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart';

void main() {
  group('CacheRepository & BootstrapCoordinator tests', () {
    test(
      'applyPage updates checkpoint and accepted cache atomically',
      () async {
        final store = PartitionStore();
        await store.unlock(
          const PartitionId(actorId: 'act-1', farmId: 'farm-1'),
        );
        final cache = CacheRepository(store: store);

        final page = {
          'scope_version': 1,
          'as_of': '2026-10-01T08:00:00Z',
          'changes': [
            {
              'resource_type': 'cage',
              'resource_id': 'cage-1',
              'action': 'upsert',
              'value': {'id': 'cage-1', 'name': 'Kandang 1'},
            },
            {
              'resource_type': 'cage',
              'resource_id': 'cage-2',
              'action': 'upsert',
              'value': {'id': 'cage-2', 'name': 'Kandang 2'},
            },
          ],
          'next_cursor': 'cursor-page-1',
          'has_more': false,
        };

        await cache.applyPage(page);

        final checkpoint = await cache.getCheckpoint();
        expect(checkpoint?.cursor, 'cursor-page-1');
        expect(checkpoint?.scopeVersion, 1);

        final cageIds = await cache.getAcceptedIds('cage');
        expect(cageIds, containsAll(['cage-1', 'cage-2']));
      },
    );

    test('reset preserves draft and outbox intents intact', () async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'act-1', farmId: 'farm-1'));
      final outbox = OutboxRepository(store: store);
      final cache = CacheRepository(store: store);

      // Enqueue pending intent
      final intent = Intent(
        id: 'stable-intent-1',
        resourceId: 'res-daily-1',
        operationId: 'createDaily',
        payload: {'feed_kg': '12.00'},
      );
      await outbox.enqueue(intent);

      // Mock transport that triggers reset
      final mockCoordinatorTransport = MockSyncTransport();
      final coordinator = BootstrapCoordinator(
        cache: cache,
        outbox: outbox,
        transport: mockCoordinatorTransport,
      );

      await coordinator.refresh();

      // Verify pending outbox intent is preserved!
      final pending = await outbox.pendingIntents();
      expect(pending, hasLength(1));
      expect(pending.first.id, 'stable-intent-1');

      // Verify accepted cache reconstructed from fresh bootstrap
      final cages = await cache.getAcceptedIds('cage');
      expect(cages, contains('cage-fresh-1'));
    });
  });
}

class MockSyncTransport implements SyncTransport {
  @override
  Future<List<Map<String, dynamic>>> fetchAllBootstrapPages() async {
    return [
      {
        'scope_version': 2,
        'as_of': '2026-10-01T09:00:00Z',
        'changes': [
          {
            'resource_type': 'cage',
            'resource_id': 'cage-fresh-1',
            'action': 'upsert',
            'value': {'id': 'cage-fresh-1', 'name': 'Kandang Fresh'},
          },
        ],
        'next_cursor': 'cursor-bootstrap-final',
        'has_more': false,
      },
    ];
  }
}
