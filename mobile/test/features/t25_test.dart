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
import 'package:mobile/features/flocks/cage_form_screen.dart';
import 'package:mobile/features/flocks/cage_form_view_model.dart';
import 'package:mobile/features/flocks/cage_list_screen.dart';
import 'package:mobile/features/flocks/cage_list_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class CageTransport implements Transport {
  JsonObject lastBody = const {};
  String? lastKey;
  ApiFailure? throwNext;

  @override
  Future<JsonObject> send(
      String operationId, JsonObject payload, String idempotencyKey) async {
    lastBody = payload;
    lastKey = idempotencyKey;
    final t = throwNext;
    if (t != null) {
      throwNext = null;
      throw t;
    }
    return {'status': 'accepted'};
  }
}

class CageApiClient extends ApiClient {
  CageApiClient() : super(baseUrl: 'http://localhost');
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
    return {'data': {'id': 'cage-1', ...?body}};
  }
}

void main() {
  group('T25 Cage list & form tests', () {
    testWidgets('kandang tersembunyi tidak muncul', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final cache = CacheRepository(store: store);
      await cache.applyPage({
        'scope_version': 1,
        'as_of': '2026-10-01T08:00:00Z',
        'changes': [
          {
            'resource_type': 'cage',
            'resource_id': 'c-1',
            'action': 'upsert',
            'value': {'id': 'c-1', 'code': 'K-01', 'name': 'Kandang A'},
          },
          {
            'resource_type': 'cage',
            'resource_id': 'c-revoked',
            'action': 'upsert',
            'value': {
              'id': 'c-revoked',
              'code': 'K-99',
              'name': 'Kandang Lama'
            },
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });

      // Operator only assigned to c-1
      final viewModel = CageListViewModel(
        cache: cache,
        assignedCageIds: {'c-1'},
      );
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: CageListScreen(viewModel: viewModel),
        ),
      );

      expect(find.textContaining('K-01'), findsOneWidget);
      expect(find.textContaining('K-99'), findsNothing);
    });

    testWidgets('duplikat kode menampilkan pemulihan pada field',
        (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'owner-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final transport = CageTransport();
      final worker = SyncWorker(
        outbox: outbox,
        transport: transport,
        retryPolicy: const RetryPolicy(),
      );
      final api = CageApiClient();
      api.throwNext = const ApiFailure(
        code: 'DUPLICATE_CODE',
        message: 'Kode kandang sudah dipakai.',
        status: 422,
        fields: {
          'code': ['Kode kandang sudah dipakai.']
        },
      );

      final viewModel = CageFormViewModel(
        apiClient: api,
        outbox: outbox,
        worker: worker,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: CageFormScreen(viewModel: viewModel),
        ),
      );

      await tester.enterText(find.byKey(const Key('cage-code')), 'K-01');
      await tester.enterText(find.byKey(const Key('cage-name')), 'Kandang A');
      await tester.tap(find.text('Simpan kandang'));
      await tester.pumpAndSettle();

      expect(find.text('Kode kandang sudah dipakai.'), findsOneWidget);
      // Value preserved
      expect(find.text('K-01'), findsOneWidget);
    });
  });
}
