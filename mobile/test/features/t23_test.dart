import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/core/sync/retry_policy.dart';
import 'package:mobile/core/sync/sync_worker.dart';
import 'package:mobile/features/daily/daily_history_screen.dart';
import 'package:mobile/features/daily/daily_history_view_model.dart';
import 'package:mobile/features/sync/sync_center_screen.dart';
import 'package:mobile/features/sync/sync_center_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class RejectingTransport implements Transport {
  ApiFailure? _nextRejection;

  void rejectNext(String code, int status) {
    _nextRejection = ApiFailure(
      code: code,
      message: 'Stok pakan tidak cukup untuk operasi ini.',
      status: status,
      retryable: false,
    );
  }

  @override
  Future<JsonObject> send(
      String operationId, JsonObject payload, String idempotencyKey) async {
    final rejection = _nextRejection;
    if (rejection != null) {
      _nextRejection = null;
      throw rejection;
    }
    return {'status': 'accepted'};
  }
}

void main() {
  group('T23 History & Sync Center tests', () {
    testWidgets('422 menyimpan payload untuk ditinjau', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final cache = CacheRepository(store: store);
      final transport = RejectingTransport();
      final worker = SyncWorker(
        outbox: outbox,
        transport: transport,
        retryPolicy: const RetryPolicy(),
      );

      // Operator records a daily entry offline
      await outbox.enqueue(outbox_lib.Intent(
        id: 'intent-1',
        resourceId: 'daily-1',
        operationId: 'createDaily',
        payload: const {
          'id': 'daily-1',
          'flock_id': 'flock-1',
          'business_date': '2026-10-01',
          'feed_kg': '12.50',
          'eggs_count': 320,
        },
      ));

      // Server rejects with 422 INSUFFICIENT_STOCK
      transport.rejectNext('INSUFFICIENT_STOCK', 422);
      await worker.runOnce();

      final viewModel = SyncCenterViewModel(
        outbox: outbox,
        worker: worker,
        cache: cache,
      );
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: SyncCenterScreen(viewModel: viewModel),
        ),
      );

      expect(find.text('Perlu ditinjau'), findsOneWidget);
      final pending = await outbox.pendingIntents();
      // The item is kept (needsReview), not discarded
      final reviewItems = viewModel.items
          .where((i) => i.state == outbox_lib.IntentState.needsReview)
          .toList();
      expect(reviewItems, hasLength(1));
      expect(reviewItems.first.payload['feed_kg'], '12.50');
      expect(pending, hasLength(0));
    });

    testWidgets('riwayat memfilter kandang dan tanggal', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final cache = CacheRepository(store: store);
      await cache.applyPage({
        'scope_version': 1,
        'as_of': '2026-10-01T08:00:00Z',
        'changes': [
          {
            'resource_type': 'daily',
            'resource_id': 'd-1',
            'action': 'upsert',
            'value': {
              'id': 'd-1',
              'cage_id': 'c-1',
              'business_date': '2026-10-01',
              'feed_kg': '12.50',
              'eggs_count': 320,
            },
          },
          {
            'resource_type': 'daily',
            'resource_id': 'd-2',
            'action': 'upsert',
            'value': {
              'id': 'd-2',
              'cage_id': 'c-2',
              'business_date': '2026-09-30',
              'feed_kg': '10.00',
              'eggs_count': 300,
            },
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });

      final viewModel = DailyHistoryViewModel(cache: cache);
      await viewModel.filter({'cage_id': 'c-1', 'date': '2026-10-01'});

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: DailyHistoryScreen(viewModel: viewModel),
        ),
      );

      expect(viewModel.rows, hasLength(1));
      expect(viewModel.rows.first.id, 'd-1');
    });
  });
}
