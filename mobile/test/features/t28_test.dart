import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/core/sync/retry_policy.dart';
import 'package:mobile/core/sync/sync_worker.dart';
import 'package:mobile/features/feed/feed_entry_screen.dart';
import 'package:mobile/features/feed/feed_entry_view_model.dart';
import 'package:mobile/features/feed/feed_stock_screen.dart';
import 'package:mobile/features/feed/feed_stock_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class FeedTransport implements Transport {
  JsonObject lastBody = const {};
  String? lastKey;

  @override
  Future<JsonObject> send(
      String operationId, JsonObject payload, String idempotencyKey) async {
    lastBody = payload;
    lastKey = idempotencyKey;
    return {'status': 'accepted'};
  }
}

class FeedApiClient extends ApiClient {
  FeedApiClient() : super(baseUrl: 'http://localhost');
  JsonObject? lastBody;
  String? lastIdempotencyKey;
  ApiFailure? throwNext;

  @override
  Future<JsonObject> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    JsonObject? body,
    String? idempotencyKey,
  }) async {
    lastBody = body;
    lastIdempotencyKey = idempotencyKey;
    final t = throwNext;
    if (t != null) {
      throwNext = null;
      throw t;
    }
    return {'data': {'id': 'entry-1', ...?body}};
  }
}

void main() {
  group('T28 Feed stock & entry tests', () {
    testWidgets('stok stale menampilkan waktu snapshot', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'owner-1', farmId: 'farm-1'));
      final cache = CacheRepository(store: store);
      await cache.applyPage({
        'scope_version': 1,
        'as_of': '2026-10-01T06:00:00Z',
        'changes': [
          {
            'resource_type': 'feed_balance',
            'resource_id': 'fb-1',
            'action': 'upsert',
            'value': {
              'id': 'fb-1',
              'feed_type_id': 'ft-1',
              'balance_kg': '300.00',
              'as_of': '2026-10-01T06:00:00Z',
            },
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });

      final viewModel = FeedStockViewModel(cache: cache);
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FeedStockScreen(viewModel: viewModel),
        ),
      );

      expect(find.textContaining('Terakhir diperbarui'), findsWidgets);
    });

    testWidgets('server menolak saldo negatif, isian dipertahankan',
        (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'owner-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final worker = SyncWorker(
        outbox: outbox,
        transport: FeedTransport(),
        retryPolicy: const RetryPolicy(),
      );
      final api = FeedApiClient();
      api.throwNext = const ApiFailure(
        code: 'NEGATIVE_BALANCE',
        message: 'Saldo pakan tidak boleh negatif.',
        status: 422,
        retryable: false,
      );

      final viewModel = FeedEntryViewModel(
        apiClient: api,
        outbox: outbox,
        worker: worker,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FeedEntryScreen(viewModel: viewModel),
        ),
      );

      await tester.enterText(find.byKey(const Key('feed-amount')), '10.00');
      await tester.tap(find.text('Simpan transaksi'));
      await tester.pumpAndSettle();

      expect(find.text('Saldo pakan tidak boleh negatif.'), findsOneWidget);
      expect(find.text('10.00'), findsOneWidget);
    });
  });
}
