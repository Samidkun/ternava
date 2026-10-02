// Test-only screen gallery: builds every screen from the preview manifest at
// any of its declared states. This is a *harness*, not a production screen.
//
// The production anchors are the screens and view models under lib/. The
// gallery only wires fake repositories/API clients so the widget tree can be
// pumped for every (screen, state) pair. It must never replace a real-device
// check (TalkBack, camera, OS-level storage faults) — see
// docs/evidence/android-uat.md.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/bootstrap_coordinator.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart';
import 'package:mobile/core/sync/sync_worker.dart';
import 'package:mobile/features/access/account_screen.dart';
import 'package:mobile/features/access/account_view_model.dart';
import 'package:mobile/features/access/farm_setup_screen.dart';
import 'package:mobile/features/access/farm_setup_view_model.dart';
import 'package:mobile/features/access/login_screen.dart';
import 'package:mobile/features/access/login_view_model.dart';
import 'package:mobile/features/access/member_form_screen.dart';
import 'package:mobile/features/access/member_form_view_model.dart';
import 'package:mobile/features/access/team_list_screen.dart';
import 'package:mobile/features/access/team_list_view_model.dart';
import 'package:mobile/features/daily/daily_form_screen.dart';
import 'package:mobile/features/daily/daily_form_view_model.dart';
import 'package:mobile/features/daily/daily_history_screen.dart';
import 'package:mobile/features/daily/daily_history_view_model.dart';
import 'package:mobile/features/daily/today_screen.dart';
import 'package:mobile/features/daily/today_view_model.dart';
import 'package:mobile/features/feed/feed_entry_screen.dart';
import 'package:mobile/features/feed/feed_entry_view_model.dart';
import 'package:mobile/features/feed/feed_stock_screen.dart';
import 'package:mobile/features/feed/feed_stock_view_model.dart';
import 'package:mobile/features/feed/feed_type_form_screen.dart';
import 'package:mobile/features/feed/feed_type_form_view_model.dart';
import 'package:mobile/features/flocks/cage_form_screen.dart';
import 'package:mobile/features/flocks/cage_form_view_model.dart';
import 'package:mobile/features/flocks/cage_list_screen.dart';
import 'package:mobile/features/flocks/cage_list_view_model.dart';
import 'package:mobile/features/flocks/flock_form_screen.dart';
import 'package:mobile/features/flocks/flock_form_view_model.dart';
import 'package:mobile/features/flocks/flock_list_screen.dart';
import 'package:mobile/features/flocks/flock_list_view_model.dart';
import 'package:mobile/features/incidents/incident_detail_screen.dart';
import 'package:mobile/features/incidents/incident_detail_view_model.dart';
import 'package:mobile/features/incidents/incident_form_screen.dart';
import 'package:mobile/features/incidents/incident_form_view_model.dart';
import 'package:mobile/features/incidents/incident_list_screen.dart';
import 'package:mobile/features/incidents/incident_list_view_model.dart';
import 'package:mobile/features/insights/home_screen.dart';
import 'package:mobile/features/insights/home_view_model.dart';
import 'package:mobile/features/insights/inbox_screen.dart';
import 'package:mobile/features/insights/inbox_view_model.dart';
import 'package:mobile/features/insights/reports_screen.dart';
import 'package:mobile/features/insights/reports_view_model.dart';
import 'package:mobile/features/sync/sync_center_screen.dart';
import 'package:mobile/features/sync/sync_center_view_model.dart';
import 'package:mobile/features/tasks/task_detail_screen.dart';
import 'package:mobile/features/tasks/task_detail_view_model.dart';
import 'package:mobile/features/tasks/task_form_screen.dart';
import 'package:mobile/features/tasks/task_form_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

/// Coarse state category inferred from a manifest state name. Screens do not
/// all model every state distinctly; the gallery maps each name onto the
/// closest real behaviour the production code supports.
enum GalleryStateMode { normal, empty, loading, failing, stale, restricted }

GalleryStateMode galleryModeFor(String state) {
  final s = state.toLowerCase();
  if (s.contains('loading') || s.contains('pending')) {
    return GalleryStateMode.loading;
  }
  if (s.contains('empty')) return GalleryStateMode.empty;
  if (s.contains('stale')) return GalleryStateMode.stale;
  if (s.contains('error') ||
      s.contains('offline') ||
      s.contains('local-failure') ||
      s.contains('export-failure') ||
      s.contains('conflict') ||
      s.contains('missing') ||
      s.contains('expired') ||
      s.contains('unavailable') ||
      s.contains('duplicate') ||
      s.contains('password-required') ||
      s.contains('notification-denied') ||
      s.contains('logout-pending') ||
      s.contains('photo-pending') ||
      s.contains('read-only') ||
      s.contains('unassigned')) {
    return GalleryStateMode.failing;
  }
  if (s.contains('restricted') ||
      s.contains('denied') ||
      s.contains('owner-protected')) {
    return GalleryStateMode.restricted;
  }
  return GalleryStateMode.normal;
}

/// A fake API client whose behaviour is driven by [mode]. It returns a small
/// but contract-shaped payload for the operations the screens actually call.
class GalleryApiClient extends ApiClient {
  GalleryStateMode mode;

  GalleryApiClient({this.mode = GalleryStateMode.normal})
      : super(baseUrl: 'http://localhost');

  @override
  Future<JsonObject> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    JsonObject? body,
    String? idempotencyKey,
  }) async {
    switch (mode) {
      case GalleryStateMode.loading:
        // Never completes: lets the screen settle on its loading affordance.
        return Completer<JsonObject>().future;
      case GalleryStateMode.failing:
        throw const ApiFailure(
          code: 'NETWORK_ERROR',
          message: 'Tidak dapat terhubung ke server.',
          status: 0,
          retryable: true,
        );
      case GalleryStateMode.restricted:
        throw const ApiFailure(
          code: 'FORBIDDEN',
          message: 'Anda tidak memiliki akses ke data ini.',
          status: 403,
        );
      case GalleryStateMode.empty:
      case GalleryStateMode.stale:
      case GalleryStateMode.normal:
        return _okPayload(operationId);
    }
  }

  JsonObject _okPayload(String operationId) {
    switch (operationId) {
      case 'session':
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
      case 'login':
        return {
          'data': {
            'token': 'token-test',
            'must_change_password': false,
            'actor': {
              'id': 'operator-budi',
              'farm_id': 'farm-test-01',
            },
          },
        };
      case 'dashboard':
        return {
          'data': {
            'business_date': '2026-10-02',
            'timezone': 'Asia/Jakarta',
            'as_of': '2026-10-02T06:00:00Z',
            'expected_records': 2,
            'accepted_records': 2,
            'eggs_count': 85,
            'feed_kg': '12.50',
            'open_incidents': 0,
            'low_stock_feed_type_ids': <String>[],
            'cages': [
              {
                'cage_id': 'cage-1',
                'flock_id': 'flock-1',
                'record_state': 'accepted',
                'eggs_count': 45,
                'feed_kg': '6.25',
              },
            ],
          },
        };
      case 'operationsReport':
        return {
          'data': {
            'from': '2026-10-01',
            'to': '2026-10-02',
            'timezone': 'Asia/Jakarta',
            'as_of': '2026-10-02T06:00:00Z',
            'expected_records': 2,
            'accepted_records': 2,
            'eggs_count': 85,
            'feed_kg': '12.50',
            'rows': <JsonObject>[],
          },
        };
      case 'exportReport':
        return {'data': {'download_url': 'https://example.invalid/report.csv'}};
      case 'listInbox':
        return {'data': <JsonObject>[]};
      case 'listMember':
        return {'data': <JsonObject>[]};
      case 'readInbox':
        return {'data': <String, Object?>{}};
      default:
        return {
          'data': {'id': 'gen-1', 'version': 1},
        };
    }
  }
}

/// Transport used by the sync worker and the bootstrap coordinator.
class GalleryTransport implements Transport, SyncTransport {
  bool offline;
  int businessEffects = 0;

  GalleryTransport({this.offline = false});

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
    return {'data': {'id': payload['id'] ?? 'gen-1'}};
  }

  @override
  Future<List<JsonObject>> fetchAllBootstrapPages() async => <JsonObject>[];
}

/// Builds a screen widget for a (screenId, state) pair.
class ScreenGallery {
  final PartitionStore store;
  final CacheRepository cache;
  final OutboxRepository outbox;
  final GalleryTransport transport;
  final SyncWorker worker;
  final BootstrapCoordinator coordinator;

  ScreenGallery({
    required this.store,
    required this.cache,
    required this.outbox,
    required this.transport,
    required this.worker,
    required this.coordinator,
  });

  static const String farmId = 'farm-test-01';
  static const String operatorId = 'operator-budi';

  /// Seeds accepted cache rows for a resource type via a synthetic sync page.
  Future<void> seed(String resourceType, List<JsonObject> rows) async {
    final changes = <Map<String, dynamic>>[];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final id = (row['id'] ??
              row['feed_type_id'] ??
              row['cage_id'] ??
              '$resourceType-$i')
          .toString();
      changes.add(<String, dynamic>{
        'resource_type': resourceType,
        'resource_id': id,
        'action': 'upsert',
        'value': Map<String, dynamic>.from(row),
      });
    }
    await cache.applyPage(<String, dynamic>{
      'next_cursor': 'seed-$resourceType',
      'scope_version': 1,
      'as_of': DateTime.now().toUtc().toIso8601String(),
      'changes': changes,
    });
  }

  Widget appAt(String screenId, {Map<String, Object?>? args}) {
    final state = (args?['state'] as String?) ?? 'default';
    final mode = galleryModeFor(state);
    final api = GalleryApiClient(mode: mode);
    final loginApi = GalleryApiClient(
      mode: mode == GalleryStateMode.restricted ? GalleryStateMode.normal : mode,
    );

    final screen = _build(screenId, state, mode, api, loginApi);
    return MaterialApp(
      theme: TernavaTheme.light(),
      home: screen,
      routes: {
        '/login': (_) => LoginScreen(
              viewModel: LoginViewModel(
                apiClient: loginApi,
                coordinator: coordinator,
                store: store,
              ),
            ),
      },
    );
  }

  Widget _build(
    String screenId,
    String state,
    GalleryStateMode mode,
    GalleryApiClient api,
    GalleryApiClient loginApi,
  ) {
    switch (screenId) {
      case 'login':
        return LoginScreen(
          viewModel: LoginViewModel(
            apiClient: loginApi,
            coordinator: coordinator,
            store: store,
          ),
        );
      case 'farm-setup':
        return FarmSetupScreen(
          viewModel: FarmSetupViewModel(
            apiClient: api,
            outbox: outbox,
            worker: worker,
          ),
        );
      case 'cage-list':
        return CageListScreen(viewModel: CageListViewModel(cache: cache));
      case 'cage-form':
        return CageFormScreen(
          viewModel: CageFormViewModel(
            apiClient: api,
            outbox: outbox,
            worker: worker,
          ),
        );
      case 'flock-list':
        return FlockListScreen(viewModel: FlockListViewModel(cache: cache));
      case 'flock-form':
        return FlockFormScreen(
          viewModel: FlockFormViewModel(
            apiClient: api,
            outbox: outbox,
            worker: worker,
            edit: state == 'edit',
            initial: state == 'edit' || state == 'duplicate'
                ? const {'id': 'flock-1', 'name': 'Kelompok A', 'version': 1}
                : null,
          ),
        );
      case 'team-list':
        return TeamListScreen(
          viewModel: TeamListViewModel(apiClient: api, outbox: outbox),
        );
      case 'member-form':
        return MemberFormScreen(
          viewModel: MemberFormViewModel(
            apiClient: api,
            outbox: outbox,
            role: state == 'restricted' ? 'admin' : 'owner',
          ),
          edit: state == 'edit',
          initial: state == 'edit' || state == 'owner-protected'
              ? const {
                  'id': 'member-1',
                  'username': 'operator_budi',
                  'display_name': 'Budi Santoso',
                  'role': 'operator',
                }
              : null,
        );
      case 'home':
        return HomeScreen(viewModel: HomeViewModel(apiClient: api));
      case 'today':
        return TodayScreen(viewModel: TodayViewModel(cache: cache));
      case 'task-form':
        return TaskFormScreen(
          viewModel: TaskFormViewModel(apiClient: api, outbox: outbox),
        );
      case 'task-detail':
        return TaskDetailScreen(
          viewModel: TaskDetailViewModel(
            cache: cache,
            outbox: outbox,
            apiClient: api,
            runId: 'run-1',
          ),
        );
      case 'daily-form':
        return DailyFormScreen(
          viewModel: DailyFormViewModel(
            outbox: outbox,
            flockId: 'flock-1',
            cageName: 'Kandang A',
            businessDate: '2026-10-02',
          ),
        );
      case 'daily-history':
        return DailyHistoryScreen(
          viewModel: DailyHistoryViewModel(cache: cache),
        );
      case 'feed-stock':
        return FeedStockScreen(viewModel: FeedStockViewModel(cache: cache));
      case 'feed-entry':
        return FeedEntryScreen(
          viewModel: FeedEntryViewModel(
            apiClient: api,
            outbox: outbox,
            worker: worker,
          ),
        );
      case 'feed-type-form':
        return FeedTypeFormScreen(
          viewModel: FeedTypeFormViewModel(
            apiClient: api,
            outbox: outbox,
            edit: state == 'edit',
            initial: state == 'edit'
                ? const {
                    'id': 'feed-1',
                    'name': 'Pakan Layer',
                    'min_threshold_kg': '50.00',
                    'version': 1,
                  }
                : null,
          ),
        );
      case 'incident-list':
        return IncidentListScreen(
          viewModel: IncidentListViewModel(cache: cache),
        );
      case 'incident-form':
        return IncidentFormScreen(
          viewModel: IncidentFormViewModel(apiClient: api, outbox: outbox),
        );
      case 'incident-detail':
        return IncidentDetailScreen(
          viewModel: IncidentDetailViewModel(
            cache: cache,
            outbox: outbox,
            apiClient: api,
            incidentId: 'incident-1',
            role: state == 'restricted' ? 'operator' : 'admin',
            actorId: operatorId,
          ),
        );
      case 'reports':
        return ReportsScreen(viewModel: ReportsViewModel(apiClient: api));
      case 'inbox':
        return InboxScreen(
          viewModel: InboxViewModel(
            apiClient: api,
            targets: _GalleryTargets(),
            onOpen: (_, _) async {},
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
      case 'account':
        return AccountScreen(
          viewModel: AccountViewModel(apiClient: api, store: store),
        );
      default:
        return Scaffold(
          appBar: AppBar(title: Text('Tidak dikenal: $screenId')),
          body: const Center(child: Text('Layar tidak dikenal.')),
        );
    }
  }
}

class _GalleryTargets implements TargetAccess {
  @override
  Future<void> requireAccess(String resourceType, String resourceId) async {}
}
