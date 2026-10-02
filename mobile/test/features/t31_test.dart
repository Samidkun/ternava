import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/task_result_input.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/features/tasks/task_detail_screen.dart';
import 'package:mobile/features/tasks/task_detail_view_model.dart';
import 'package:mobile/features/tasks/task_form_screen.dart';
import 'package:mobile/features/tasks/task_form_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class TaskApiClient extends ApiClient {
  TaskApiClient() : super(baseUrl: 'http://localhost');
  JsonObject? lastBody;
  String? lastKey;
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
    lastKey = idempotencyKey;
    final t = throwNext;
    if (t != null) {
      throwNext = null;
      throw t;
    }
    return {
      'data': {'id': 'run-1', ...?body},
    };
  }
}

JsonObject runPayload({String status = 'open', int version = 1}) => {
  'id': 'run-1',
  'farm_id': 'farm-1',
  'template_id': 'tpl-1',
  'cage_id': 'cage-1',
  'business_date': '2026-10-02',
  'scheduled_at': '2026-10-02T06:30:00Z',
  'title': 'Bersihkan tempat pakan',
  'sop': 'Sikat tempat pakan\nBuang sisa pakan basah\nIsi pakan baru',
  'assignee_id': 'operator-1',
  'status': status,
  'latest_note': null,
  'checklist_items': [
    {'id': 'c-1', 'label': 'Sikat tempat pakan'},
    {'id': 'c-2', 'label': 'Buang sisa pakan basah'},
    {'id': 'c-3', 'label': 'Isi pakan baru'},
  ],
  'version': version,
};

Future<CacheRepository> cacheWithRun(JsonObject run) async {
  final store = PartitionStore();
  await store.unlock(
    const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
  );
  final cache = CacheRepository(store: store);
  await cache.applyPage({
    'scope_version': 1,
    'as_of': '2026-10-02T06:00:00Z',
    'changes': [
      {
        'resource_type': 'task_run',
        'resource_id': run['id'],
        'action': 'upsert',
        'value': run,
      },
    ],
    'next_cursor': null,
    'has_more': false,
  });
  return cache;
}

void main() {
  group('T31 Task operator tests', () {
    testWidgets('menandai satu SOP tidak melengkapi semua', (tester) async {
      final cache = await cacheWithRun(runPayload());
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = TaskDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: TaskApiClient(),
        runId: 'run-1',
      );
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: TaskDetailScreen(viewModel: viewModel),
        ),
      );

      await tester.tap(find.byKey(const Key('check-item-1')));
      await tester.pump();

      expect(viewModel.isChecked('c-1'), isTrue);
      expect(viewModel.isChecked('c-2'), isFalse);
      expect(
        tester
            .widget<CheckboxListTile>(find.byKey(const Key('check-item-2')))
            .value,
        isFalse,
      );
    });

    testWidgets('SOP ditampilkan literal dan tidak ada saran medis', (
      tester,
    ) async {
      final cache = await cacheWithRun(runPayload());
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = TaskDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: TaskApiClient(),
        runId: 'run-1',
      );
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: TaskDetailScreen(viewModel: viewModel),
        ),
      );

      expect(find.text('Sikat tempat pakan'), findsWidgets);
      expect(find.textContaining('dosis'), findsNothing);
      expect(find.textContaining('diagnosis'), findsNothing);
    });

    testWidgets('hasil note tidak menutup tugas', (tester) async {
      final cache = await cacheWithRun(runPayload());
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = TaskApiClient();
      final viewModel = TaskDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        runId: 'run-1',
      );
      await viewModel.load();

      final payload = TaskResultInput.fromJson({
        'id': 'res-1',
        'base_version': 1,
        'status': 'note',
        'notes': 'Kandang masih lembap',
        'checklist_values': [
          {'id': 'c-1', 'checked': true},
        ],
      });

      await viewModel.submit(payload);

      expect(api.lastBody!['status'], 'note');
      expect(viewModel.runStatus, 'open');
    });

    testWidgets('hasil completed menutup tugas dan menjadi read-only', (
      tester,
    ) async {
      final cache = await cacheWithRun(runPayload());
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = TaskApiClient();
      final viewModel = TaskDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        runId: 'run-1',
      );
      await viewModel.load();

      await viewModel.submit(
        TaskResultInput.fromJson({
          'id': 'res-2',
          'base_version': 1,
          'status': 'completed',
          'notes': null,
          'checklist_values': [
            {'id': 'c-1', 'checked': true},
            {'id': 'c-2', 'checked': true},
            {'id': 'c-3', 'checked': true},
          ],
        }),
      );

      expect(viewModel.runStatus, 'completed');
      expect(viewModel.isReadOnly, isTrue);
    });

    testWidgets('hasil offline disimpan sebagai intent lokal', (tester) async {
      final cache = await cacheWithRun(runPayload());
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = TaskApiClient();
      api.throwNext = const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server.',
        status: 0,
        retryable: true,
      );
      final viewModel = TaskDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        runId: 'run-1',
      );
      await viewModel.load();

      await viewModel.submit(
        TaskResultInput.fromJson({
          'id': 'res-3',
          'base_version': 1,
          'status': 'note',
          'notes': 'Catatan offline',
          'checklist_values': [],
        }),
      );

      final intents = await outbox.allIntents();
      expect(intents.length, 1);
      expect(intents.first.operationId, 'createTaskResult');
      expect(intents.first.resourceId, 'run-1');
    });

    testWidgets('run dibatalkan menjadi needs review', (tester) async {
      final cache = await cacheWithRun(runPayload(status: 'cancelled'));
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'operator-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = TaskApiClient();
      api.throwNext = const ApiFailure(
        code: 'VERSION_CONFLICT',
        message: 'Tugas sudah dibatalkan.',
        status: 409,
        retryable: false,
      );
      final viewModel = TaskDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        runId: 'run-1',
      );
      await viewModel.load();

      await viewModel.submit(
        TaskResultInput.fromJson({
          'id': 'res-4',
          'base_version': 1,
          'status': 'completed',
          'notes': null,
          'checklist_values': [],
        }),
      );

      expect(viewModel.needsReview, isTrue);
    });

    testWidgets('template tugas disimpan online', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = TaskApiClient();
      final viewModel = TaskFormViewModel(apiClient: api, outbox: outbox);

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: TaskFormScreen(viewModel: viewModel),
        ),
      );

      await tester.enterText(find.byKey(const Key('task-title')), 'Bersihkan');
      await tester.tap(find.text('Simpan tugas'));
      await tester.pumpAndSettle();

      expect(api.lastKey, isNotNull);
      expect(api.lastBody!['title'], 'Bersihkan');
    });
  });
}
