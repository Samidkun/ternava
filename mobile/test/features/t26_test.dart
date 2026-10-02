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
import 'package:mobile/features/flocks/flock_form_screen.dart';
import 'package:mobile/features/flocks/flock_form_view_model.dart';
import 'package:mobile/features/flocks/flock_list_screen.dart';
import 'package:mobile/features/flocks/flock_list_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class FlockTransport implements Transport {
  JsonObject lastBody = const {};
  String? lastKey;

  @override
  Future<JsonObject> send(
    String operationId,
    JsonObject payload,
    String idempotencyKey,
  ) async {
    lastBody = payload;
    lastKey = idempotencyKey;
    return {'status': 'accepted'};
  }
}

class FlockApiClient extends ApiClient {
  FlockApiClient() : super(baseUrl: 'http://localhost');
  JsonObject? lastBody;
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
    final t = throwNext;
    if (t != null) {
      throwNext = null;
      throw t;
    }
    return {
      'data': {'id': 'flock-1', ...?body},
    };
  }
}

void main() {
  group('T26 Flock list & form tests', () {
    testWidgets('edit kelompok mencatat alasan dan kunci populasi awal', (
      tester,
    ) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final worker = SyncWorker(
        outbox: outbox,
        transport: FlockTransport(),
        retryPolicy: const RetryPolicy(),
      );

      final viewModel = FlockFormViewModel(
        apiClient: FlockApiClient(),
        outbox: outbox,
        worker: worker,
        edit: true,
        initial: {
          'id': 'flock-1',
          'name': 'Kelompok 1',
          'initial_population': 500,
          'version': 3,
          'has_operations': true,
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FlockFormScreen(viewModel: viewModel),
        ),
      );

      expect(find.byKey(const Key('change-reason')), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const Key('initial-population')),
      );
      expect(field.enabled, isFalse);
    });

    testWidgets('filter kelompok aktif dan selesai', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final cache = CacheRepository(store: store);
      await cache.applyPage({
        'scope_version': 1,
        'as_of': '2026-10-01T08:00:00Z',
        'changes': [
          {
            'resource_type': 'flock',
            'resource_id': 'f-1',
            'action': 'upsert',
            'value': {
              'id': 'f-1',
              'name': 'Kelompok Aktif',
              'status': 'active',
              'start_date': '2026-09-01',
            },
          },
          {
            'resource_type': 'flock',
            'resource_id': 'f-2',
            'action': 'upsert',
            'value': {
              'id': 'f-2',
              'name': 'Kelompok Selesai',
              'status': 'finished',
              'start_date': '2026-06-01',
              'end_date': '2026-08-30',
            },
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });

      final viewModel = FlockListViewModel(cache: cache);
      await viewModel.filter('active');

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FlockListScreen(viewModel: viewModel),
        ),
      );

      expect(find.text('Kelompok Aktif'), findsOneWidget);
      expect(find.text('Kelompok Selesai'), findsNothing);
    });
  });
}
