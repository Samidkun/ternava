import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/incident_action_input.dart';
import 'package:mobile/core/api/generated/incident_assignment_input.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incident_detail_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class IncidentDetailApiClient extends ApiClient {
  IncidentDetailApiClient() : super(baseUrl: 'http://localhost');
  JsonObject? lastBody;
  String? lastOp;
  ApiFailure? throwNext;

  @override
  Future<JsonObject> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    JsonObject? body,
    String? idempotencyKey,
  }) async {
    lastOp = operationId;
    lastBody = body;
    final t = throwNext;
    if (t != null) {
      throwNext = null;
      throw t;
    }
    return {'data': {'id': 'inc-1', 'version': 2}};
  }
}

JsonObject incidentJson({
  String id = 'inc-1',
  String status = 'open',
  String? assigneeId,
  int version = 1,
}) =>
    {
      'id': id,
      'farm_id': 'farm-1',
      'cage_id': 'cage-1',
      'flock_id': 'flock-1',
      'source_daily_record_id': null,
      'observed_at': '2026-10-02T06:30:00Z',
      'observation': 'Ayam lemas di blok A3',
      'attention': 'priority',
      'assignee_id': assigneeId,
      'status': status,
      'version': version,
      'updated_at': '2026-10-02T06:30:00Z',
    };

Future<CacheRepository> cacheWith(JsonObject incident) async {
  final store = PartitionStore();
  await store.unlock(const PartitionId(actorId: 'owner-1', farmId: 'farm-1'));
  final cache = CacheRepository(store: store);
  await cache.applyPage({
    'scope_version': 1,
    'as_of': '2026-10-02T06:00:00Z',
    'changes': [
      {
        'resource_type': 'incident',
        'resource_id': incident['id'],
        'action': 'upsert',
        'value': incident,
      },
    ],
    'next_cursor': null,
    'has_more': false,
  });
  return cache;
}

Future<outbox_lib.OutboxRepository> freshOutbox() async {
  final store = PartitionStore();
  await store.unlock(const PartitionId(actorId: 'owner-1', farmId: 'farm-1'));
  return outbox_lib.OutboxRepository(store: store);
}

void main() {
  group('T34 Incident detail tests', () {
    testWidgets('close tanpa catatan ditolak', (tester) async {
      final cache = await cacheWith(incidentJson());
      final outbox = await freshOutbox();
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: IncidentDetailApiClient(),
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: IncidentDetailScreen(viewModel: viewModel),
        ),
      );

      await tester.tap(find.text('Tutup temuan'));
      await tester.pump();

      expect(find.text('Jelaskan tindakan sebelum menutup temuan.'),
          findsOneWidget);
    });

    testWidgets('close dengan catatan mengirim aksi', (tester) async {
      final cache = await cacheWith(incidentJson());
      final outbox = await freshOutbox();
      final api = IncidentDetailApiClient();
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      await viewModel.act(IncidentActionInput.fromJson({
        'id': 'act-1',
        'base_version': 1,
        'notes': 'Sudah dipisahkan',
        'status': 'closed',
      }));

      expect(api.lastOp, 'createIncidentAction');
      expect(api.lastBody!['status'], 'closed');
      expect(viewModel.status, 'closed');
    });

    testWidgets('temuan tertutup menjadi read-only', (tester) async {
      final cache = await cacheWith(incidentJson(status: 'closed', version: 3));
      final outbox = await freshOutbox();
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: IncidentDetailApiClient(),
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      expect(viewModel.isReadOnly, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: IncidentDetailScreen(viewModel: viewModel),
        ),
      );

      expect(find.text('Tutup temuan'), findsNothing);
    });

    testWidgets('konflik versi memuat ulang dan mempertahankan catatan',
        (tester) async {
      final cache = await cacheWith(incidentJson());
      final outbox = await freshOutbox();
      final api = IncidentDetailApiClient();
      api.throwNext = const ApiFailure(
        code: 'VERSION_CONFLICT',
        message: 'Temuan sudah berubah.',
        status: 409,
        retryable: false,
      );
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      await viewModel.act(IncidentActionInput.fromJson({
        'id': 'act-1',
        'base_version': 1,
        'notes': 'Catatan penting saya',
        'status': 'in_progress',
      }));

      expect(viewModel.hasConflict, isTrue);
      // The user's notes survive the conflict so nothing is retyped.
      expect(viewModel.pendingNotes, 'Catatan penting saya');
    });

    testWidgets('operator hanya melihat tombol untuk temuan yang ditugaskan',
        (tester) async {
      final cache = await cacheWith(incidentJson(assigneeId: 'op-9'));
      final outbox = await freshOutbox();
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: IncidentDetailApiClient(),
        incidentId: 'inc-1',
        role: 'operator',
        actorId: 'op-1',
      );
      await viewModel.load();

      expect(viewModel.canAct, isFalse);
    });

    testWidgets('temuan tidak dapat diakses memberi pemulihan kembali',
        (tester) async {
      final cache = await cacheWith(incidentJson());
      final outbox = await freshOutbox();
      final api = IncidentDetailApiClient();
      api.throwNext = const ApiFailure(
        code: 'NOT_FOUND',
        message: 'Temuan tidak ditemukan.',
        status: 404,
        retryable: false,
      );
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      await viewModel.act(IncidentActionInput.fromJson({
        'id': 'act-1',
        'base_version': 1,
        'notes': 'x',
        'status': 'in_progress',
      }));

      expect(viewModel.isInaccessible, isTrue);
    });

    testWidgets('assign mencatat aktor dan riwayat tindakan', (tester) async {
      final cache = await cacheWith(incidentJson());
      final outbox = await freshOutbox();
      final api = IncidentDetailApiClient();
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      await viewModel.assign(IncidentAssignmentInput.fromJson({
        'base_version': 1,
        'assignee_id': 'op-9',
      }));

      expect(api.lastOp, 'assignIncident');
      expect(api.lastBody!['assignee_id'], 'op-9');
    });

    testWidgets('aksi offline disimpan sebagai intent lokal', (tester) async {
      final cache = await cacheWith(incidentJson());
      final outbox = await freshOutbox();
      final api = IncidentDetailApiClient();
      api.throwNext = const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server.',
        status: 0,
        retryable: true,
      );
      final viewModel = IncidentDetailViewModel(
        cache: cache,
        outbox: outbox,
        apiClient: api,
        incidentId: 'inc-1',
        role: 'owner',
      );
      await viewModel.load();

      await viewModel.act(IncidentActionInput.fromJson({
        'id': 'act-1',
        'base_version': 1,
        'notes': 'Tindakan offline',
        'status': 'in_progress',
      }));

      final intents = await outbox.allIntents();
      expect(intents.length, 1);
      expect(intents.first.operationId, 'createIncidentAction');
      expect(intents.first.resourceId, 'inc-1');
    });
  });
}
