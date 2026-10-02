import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/features/incidents/incident_form_screen.dart';
import 'package:mobile/features/incidents/incident_form_view_model.dart';
import 'package:mobile/features/incidents/incident_list_screen.dart';
import 'package:mobile/features/incidents/incident_list_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class IncidentApiClient extends ApiClient {
  IncidentApiClient() : super(baseUrl: 'http://localhost');
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
      'data': {'id': 'inc-1'},
    };
  }
}

JsonObject incidentPayload({
  String id = 'inc-1',
  String status = 'open',
  String? assigneeId,
  String cageId = 'cage-1',
  String attention = 'priority',
  String observation = 'Nafsu makan menurun',
}) => {
  'id': id,
  'farm_id': 'farm-1',
  'cage_id': cageId,
  'flock_id': 'flock-1',
  'source_daily_record_id': null,
  'observed_at': '2026-10-02T06:30:00Z',
  'observation': observation,
  'attention': attention,
  'assignee_id': assigneeId,
  'status': status,
  'version': 1,
  'updated_at': '2026-10-02T06:30:00Z',
};

Future<CacheRepository> cacheWithIncidents(List<JsonObject> incidents) async {
  final store = PartitionStore();
  await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
  final cache = CacheRepository(store: store);
  await cache.applyPage({
    'scope_version': 1,
    'as_of': '2026-10-02T06:00:00Z',
    'changes': incidents
        .map(
          (i) => {
            'resource_type': 'incident',
            'resource_id': i['id'],
            'action': 'upsert',
            'value': i,
          },
        )
        .toList(),
    'next_cursor': null,
    'has_more': false,
  });
  return cache;
}

void main() {
  group('T33 Incident list & form tests', () {
    testWidgets('filter status menyaring temuan', (tester) async {
      final cache = await cacheWithIncidents([
        incidentPayload(id: 'inc-1', status: 'open'),
        incidentPayload(id: 'inc-2', status: 'closed'),
      ]);

      final viewModel = IncidentListViewModel(cache: cache);
      await viewModel.filter({'status': 'open'});

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: IncidentListScreen(viewModel: viewModel),
        ),
      );

      expect(viewModel.rows, hasLength(1));
      expect(viewModel.rows.first.id, 'inc-1');
    });

    testWidgets('filter assignment menampilkan temuan belum ditugaskan', (
      tester,
    ) async {
      final cache = await cacheWithIncidents([
        incidentPayload(id: 'inc-1', assigneeId: null),
        incidentPayload(id: 'inc-2', assigneeId: 'op-9'),
      ]);

      final viewModel = IncidentListViewModel(cache: cache);
      await viewModel.filter({'assigned': 'unassigned'});

      expect(viewModel.rows, hasLength(1));
      expect(viewModel.rows.first.id, 'inc-1');
    });

    testWidgets('teks temuan tetap ada setelah upload gagal', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = IncidentApiClient();
      api.throwNext = const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server.',
        status: 0,
        retryable: true,
      );
      final viewModel = IncidentFormViewModel(apiClient: api, outbox: outbox);

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: IncidentFormScreen(viewModel: viewModel),
        ),
      );

      await tester.enterText(
        find.byKey(const Key('incident-observation')),
        'Nafsu makan menurun',
      );
      await tester.tap(find.text('Simpan temuan'));
      await tester.pumpAndSettle();

      // Text is preserved in the local draft even though the upload failed.
      expect(viewModel.draftObservation, 'Nafsu makan menurun');
      final intents = await outbox.allIntents();
      expect(intents.length, 1);
      expect(intents.first.operationId, 'createIncident');
      expect(intents.first.payload['observation'], 'Nafsu makan menurun');
    });

    testWidgets('draft teks tahan relaunch', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);

      final vm1 = IncidentFormViewModel(
        apiClient: IncidentApiClient(),
        outbox: outbox,
      );
      await vm1.saveDraft(observation: 'Ayam lemas di blok A3');

      // Simulate app restart: a brand new view model reads persisted drafts.
      final vm2 = IncidentFormViewModel(
        apiClient: IncidentApiClient(),
        outbox: outbox,
      );
      await vm2.loadDraft();

      expect(vm2.draftObservation, 'Ayam lemas di blok A3');
    });

    testWidgets('foto terpisah dari teks dan punya status sendiri', (
      tester,
    ) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = IncidentFormViewModel(
        apiClient: IncidentApiClient(),
        outbox: outbox,
      );

      viewModel.attachPhoto(bytes: [1, 2, 3], mediaType: 'image/jpeg');

      expect(viewModel.hasPhoto, isTrue);
      expect(viewModel.photoState, PhotoState.queued);
      // The text observation is untouched by the photo queue state.
      expect(viewModel.draftObservation, '');
    });

    testWidgets('foto rusak memberi pesan yang bisa ditindaklanjuti', (
      tester,
    ) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = IncidentFormViewModel(
        apiClient: IncidentApiClient(),
        outbox: outbox,
      );

      final ok = viewModel.attachPhoto(bytes: [0], mediaType: 'text/plain');

      expect(ok, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.errorMessage!.toLowerCase(), contains('jpeg'));
    });

    testWidgets('form baru kosong', (tester) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'op-1', farmId: 'farm-1'));
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = IncidentFormViewModel(
        apiClient: IncidentApiClient(),
        outbox: outbox,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: IncidentFormScreen(viewModel: viewModel),
        ),
      );

      expect(viewModel.draftObservation, isEmpty);
      expect(find.text('Simpan temuan'), findsOneWidget);
    });

    testWidgets('temuan tidak menyebut penyakit secara otomatis', (
      tester,
    ) async {
      final cache = await cacheWithIncidents([
        incidentPayload(observation: 'Ayam lemas di blok A3'),
      ]);
      final viewModel = IncidentListViewModel(cache: cache);
      await viewModel.filter({});

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: IncidentListScreen(viewModel: viewModel),
        ),
      );

      expect(find.textContaining('penyakit'), findsNothing);
      expect(find.textContaining('diagnosis'), findsNothing);
    });
  });
}
