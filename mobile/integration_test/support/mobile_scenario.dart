// Integration-test scenario for T42, running on a real Android device/emulator.
//
// This wires the REAL production repositories (PartitionStore, CacheRepository,
// OutboxRepository, SyncWorker, BootstrapCoordinator, PayloadCipher) behind a
// controllable transport. It deliberately does not fake the sync semantics the
// production code owns: offline sends fail, ACK-less sends keep the intent
// pending, and `relaunch()` replays the production crash-recovery path.
//
// NOTE ON PERSISTENCE: this build keeps the local store in memory (no Drift on
// disk), so `relaunch()` models the process-restart *recovery* path
// (recoverSending + bootstrap refresh) rather than a true OS process kill. The
// real-process-kill and on-disk persistence checks are recorded as a gap in
// docs/evidence/android-uat.md — they are NOT claimed as passing here.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/local/payload_cipher.dart';
import 'package:mobile/core/sync/bootstrap_coordinator.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart' hide Intent;
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib show Intent;
import 'package:mobile/core/sync/retry_policy.dart';
import 'package:mobile/core/sync/sync_worker.dart';
import 'package:mobile/features/access/account_screen.dart';
import 'package:mobile/features/access/account_view_model.dart';
import 'package:mobile/features/access/login_screen.dart';
import 'package:mobile/features/access/login_view_model.dart';
import 'package:mobile/features/daily/daily_form_screen.dart';
import 'package:mobile/features/daily/daily_form_view_model.dart';
import 'package:mobile/features/daily/today_screen.dart';
import 'package:mobile/features/daily/today_view_model.dart';
import 'package:mobile/features/incidents/incident_form_screen.dart';
import 'package:mobile/features/incidents/incident_form_view_model.dart';
import 'package:mobile/features/sync/sync_center_screen.dart';
import 'package:mobile/features/sync/sync_center_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

/// A transport that can be flipped offline, can drop the ACK *after* recording
/// the business effect (timeout-after-commit), and counts effects so tests can
/// prove an ACK-less intent is not double-applied.
class ControllableTransport implements Transport, SyncTransport {
  bool offline;
  bool dropAckAfterEffect;
  bool failPhotos;
  int businessEffects = 0;
  final List<String> sentKeys = [];
  final List<JsonObject> sentBodies = [];

  ControllableTransport({
    this.offline = false,
    this.dropAckAfterEffect = false,
    this.failPhotos = false,
  });

  @override
  Future<JsonObject> send(
    String operationId,
    JsonObject payload,
    String idempotencyKey,
  ) async {
    if (offline) {
      throw const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server.',
        status: 0,
        retryable: true,
      );
    }
    businessEffects += 1;
    sentKeys.add(idempotencyKey);
    sentBodies.add(payload);
    if (dropAckAfterEffect) {
      // Server applied the effect but the response never reached the client.
      throw const ApiFailure(
        code: 'TIMEOUT',
        message: 'Permintaan melebihi batas waktu.',
        status: 408,
        retryable: true,
      );
    }
    return {'data': {'id': payload['id'] ?? 'gen-1', 'version': 1}};
  }

  @override
  Future<List<JsonObject>> fetchAllBootstrapPages() async {
    if (offline) {
      throw const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server.',
        status: 0,
        retryable: true,
      );
    }
    return [
      {
        'scope_version': 1,
        'as_of': '2026-10-02T06:00:00Z',
        'next_cursor': 'bootstrap-1',
        'has_more': false,
        'changes': [
          {
            'resource_type': 'cage',
            'resource_id': 'cage-1',
            'action': 'upsert',
            'value': {'id': 'cage-1', 'code': 'K01', 'name': 'Kandang A'},
          },
        ],
      },
    ];
  }
}

/// API client used by the screens under test. In `offline` mode it raises the
/// same NETWORK_ERROR the real client raises on a dead socket.
class ScenarioApiClient extends ApiClient {
  final ControllableTransport transport;
  ScenarioApiClient(this.transport) : super(baseUrl: 'http://localhost');

  @override
  Future<JsonObject> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    JsonObject? body,
    String? idempotencyKey,
  }) async {
    if (transport.offline) {
      throw const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke server.',
        status: 0,
        retryable: true,
      );
    }
    if (operationId == 'session') {
      return {
        'data': {
          'actor': {
            'id': 'operator-budi',
            'username': 'operator_budi',
            'display_name': 'Budi Santoso',
            'role': 'operator',
            'farm_id': 'farm-test-01',
            'farm_name': 'Peternakan Sumber Rejeki',
            'timezone': 'Asia/Jakarta',
          },
        },
      };
    }
    if (operationId == 'login') {
      return {
        'data': {
          'token': 'token-test',
          'must_change_password': false,
          'actor': {'id': 'operator-budi', 'farm_id': 'farm-test-01'},
        },
      };
    }
    return {
      'data': {'id': body?['id'] ?? 'gen-1', 'version': 1},
    };
  }
}

class MobileScenario {
  final PartitionStore store = PartitionStore();
  final ControllableTransport transport;
  late final CacheRepository cache;
  late final OutboxRepository outbox;
  late final SyncWorker worker;
  late final BootstrapCoordinator bootstrap;

  PartitionId? _partition;

  MobileScenario({ControllableTransport? transport})
      : transport = transport ?? ControllableTransport() {
    cache = CacheRepository(store: store);
    outbox = OutboxRepository(store: store);
    worker = SyncWorker(
      outbox: outbox,
      transport: this.transport,
      retryPolicy: const RetryPolicy(),
    );
    bootstrap = BootstrapCoordinator(
      cache: cache,
      outbox: outbox,
      transport: this.transport,
    );
  }

  PartitionId get partition =>
      _partition ?? const PartitionId(actorId: 'operator-budi', farmId: 'farm-test-01');

  ScenarioApiClient get api => ScenarioApiClient(transport);

  Future<void> loginAsOperator() async {
    _partition = const PartitionId(
      actorId: 'operator-budi',
      farmId: 'farm-test-01',
    );
    await store.unlock(_partition!);
    if (!transport.offline) {
      await bootstrap.refresh();
    }
  }

  Future<void> loginAsB() async {
    _partition = const PartitionId(actorId: 'operator-sari', farmId: 'farm-test-01');
    await store.unlock(_partition!);
  }

  Future<void> logout({required bool confirmed}) async {
    if (!confirmed) return;
    await store.lock();
  }

  /// Replays the production crash-recovery path: a `sending` intent returns to
  /// `pending`, then bootstrap refresh runs (which must not touch the outbox).
  Future<void> relaunch() async {
    await outbox.recoverSending();
    if (!transport.offline) {
      await bootstrap.refresh();
    }
  }

  Future<void> enqueueDaily({
    String feedKg = '12.50',
    int eggs = 80,
  }) async {
    final id = 'daily-${DateTime.now().microsecondsSinceEpoch}';
    await outbox.enqueue(outbox_lib.Intent(
      id: 'intent-$id',
      resourceId: id,
      operationId: 'createDaily',
      payload: {
        'id': id,
        'flock_id': 'flock-1',
        'business_date': '2026-10-02',
        'feed_type_id': 'default-feed-type',
        'feed_kg': feedKg,
        'eggs_count': eggs,
      },
    ));
  }

  Future<void> enqueueIncident(String observation) async {
    final id = 'incident-${DateTime.now().microsecondsSinceEpoch}';
    final key = 'incident-$id';
    await outbox.saveDraft('incident-draft', {
      'id': 'incident-draft',
      'observation': observation,
    });
    await outbox.enqueue(outbox_lib.Intent.incident({
      'id': id,
      'cage_id': 'cage-1',
      'observed_at': '2026-10-02T06:00:00Z',
      'observation': observation,
      'attention': 'routine',
    }, key));
  }

  Future<String> incidentText() async {
    final draft = outbox.getDraft('incident-draft');
    return (draft?['observation'] as String?) ?? '';
  }

  Future<List<String>> pendingIds() async {
    final pending = await outbox.pendingIntents();
    return pending.map((i) => i.id).toList();
  }

  Future<List<String>> acceptedScopeIds() async {
    return (await cache.getAcceptedIds('cage')).toList();
  }

  Future<Uint8List> encryptAsA(Uint8List bytes) async {
    final cipher = await PayloadCipher.forPartition(
      const PartitionId(actorId: 'operator-budi', farmId: 'farm-test-01'),
    );
    return cipher.encrypt(bytes, 'daily_record:uuid-123');
  }

  Future<String> decryptCurrent(Uint8List bytes) async {
    final cipher = await PayloadCipher.forPartition(partition);
    final clear = await cipher.decrypt(bytes, 'daily_record:uuid-123');
    return String.fromCharCodes(clear);
  }

  Widget appAt(String screenId, {Map<String, Object?>? args}) {
    return MaterialApp(
      theme: TernavaTheme.light(),
      home: _build(screenId),
      routes: {
        '/login': (_) => LoginScreen(
              viewModel: LoginViewModel(
                apiClient: api,
                coordinator: bootstrap,
                store: store,
              ),
            ),
      },
    );
  }

  Widget _build(String screenId) {
    switch (screenId) {
      case 'today':
        return TodayScreen(viewModel: TodayViewModel(cache: cache));
      case 'daily-form':
        return DailyFormScreen(
          viewModel: DailyFormViewModel(
            outbox: outbox,
            flockId: 'flock-1',
            cageName: 'Kandang A',
            businessDate: '2026-10-02',
          ),
        );
      case 'sync-center':
        return SyncCenterScreen(
          viewModel: SyncCenterViewModel(
            outbox: outbox,
            worker: worker,
            cache: cache,
          ),
        );
      case 'incident-form':
        return IncidentFormScreen(
          viewModel: IncidentFormViewModel(apiClient: api, outbox: outbox),
        );
      case 'account':
        return AccountScreen(
          viewModel: AccountViewModel(apiClient: api, store: store),
        );
      case 'login':
        return LoginScreen(
          viewModel: LoginViewModel(
            apiClient: api,
            coordinator: bootstrap,
            store: store,
          ),
        );
      default:
        return const Scaffold(body: Center(child: Text('Layar tidak dikenal.')));
    }
  }
}

Future<MobileScenario> makeMobileScenario({
  ControllableTransport? transport,
}) async {
  return MobileScenario(transport: transport);
}
