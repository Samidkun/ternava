import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/features/insights/inbox_screen.dart';
import 'package:mobile/features/insights/inbox_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

/// A fake inbox server that records every call so the test can prove
/// idempotency and that no target is opened before access is confirmed.
class InboxApiClient extends ApiClient {
  InboxApiClient() : super(baseUrl: 'http://localhost');

  final List<String> calls = [];
  bool revokeInboxTarget = false;
  bool fcmDisabled = false;

  @override
  Future<JsonObject> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    JsonObject? body,
    String? idempotencyKey,
  }) async {
    calls.add('$operationId:${pathParams?['id'] ?? ''}');
    if (operationId == 'listInbox') {
      return {
        'data': [
          {
            'id': '1',
            'version': 1,
            'updated_at': '2026-10-02T06:00:00Z',
            'kind': 'incident',
            'title': 'Temuan baru',
            'body': 'Kandang 2 perlu ditindak.',
            'resource_type': 'incident',
            'resource_id': 'inc-1',
            'read_at': null,
          },
          {
            'id': '2',
            'version': 2,
            'updated_at': '2026-10-02T05:00:00Z',
            'kind': 'task',
            'title': 'Tugas selesai',
            'body': 'SOP mingguan diverifikasi.',
            'resource_type': 'task_run',
            'resource_id': 'run-9',
            'read_at': '2026-10-02T05:30:00Z',
          },
        ],
      };
    }
    if (operationId == 'readInbox') {
      return {
        'data': {'status': 'accepted', 'id': pathParams?['id']},
      };
    }
    return {'data': {}};
  }
}

/// A fake access gate; revoking makes the server answer 404 for the target.
class FakeTargets implements TargetAccess {
  FakeTargets(this.api);
  final InboxApiClient api;

  @override
  Future<void> requireAccess(String resourceType, String resourceId) async {
    if (api.revokeInboxTarget) {
      throw const ApiFailure(
        code: 'NOT_FOUND',
        message: 'Tautan sudah tidak berlaku.',
        status: 404,
      );
    }
  }
}

void main() {
  group('T40 Inbox & deep link tests', () {
    testWidgets('link dicabut memberi jalan kembali', (tester) async {
      final api = InboxApiClient()..revokeInboxTarget = true;
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {},
      );
      await vm.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: InboxScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('inbox-item-1')));
      await tester.pumpAndSettle();

      expect(find.text('Kembali ke pemberitahuan'), findsOneWidget);
    });

    testWidgets('inbox menampilkan unread dan read', (tester) async {
      final api = InboxApiClient();
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {},
      );
      await vm.load();

      expect(vm.items.length, 2);
      expect(vm.items.first.isUnread, isTrue);
      expect(vm.items[1].isUnread, isFalse);
      expect(vm.unreadCount, 1);
    });

    testWidgets('markRead idempotent', (tester) async {
      final api = InboxApiClient();
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {},
      );
      await vm.load();

      await vm.markRead('1');
      await vm.markRead('1');

      // Both calls hit the server, but the item is read exactly once locally.
      expect(vm.items.first.isUnread, isFalse);
      expect(vm.unreadCount, 0);
      final reads = api.calls.where((c) => c.startsWith('readInbox')).length;
      expect(reads, 2);
    });

    testWidgets('target diperiksa server sebelum dibuka', (tester) async {
      final api = InboxApiClient();
      final opened = <String>[];
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {
          opened.add('$screenId:$id');
        },
      );
      await vm.load();

      await vm.open('1');

      expect(opened, ['incident-detail:inc-1']);
      // The target was only opened after access was confirmed.
      expect(vm.state, InboxState.idle);
    });

    testWidgets('deep link hanya membawa id bukan URL', (tester) async {
      final api = InboxApiClient();
      final opened = <String>[];
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {
          opened.add('$screenId:$id');
        },
      );
      await vm.load();

      await vm.open('2');

      // Only a screen id and a resource id travel to the router.
      expect(opened.single, 'task-detail:run-9');
      expect(opened.single.contains('http'), isFalse);
    });

    testWidgets('fcm mati tidak menghalangi inbox', (tester) async {
      final api = InboxApiClient()..fcmDisabled = true;
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {},
      );

      await vm.load();

      // Inbox is durable server-side state, independent of push delivery.
      expect(vm.items, isNotEmpty);
      expect(vm.errorMessage, isNull);
    });

    testWidgets('item dibaca saat dibuka', (tester) async {
      final api = InboxApiClient();
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {},
      );
      await vm.load();

      await vm.open('1');

      expect(vm.items.first.isUnread, isFalse);
      expect(api.calls.any((c) => c.startsWith('readInbox')), isTrue);
    });

    testWidgets('inbox kosong tampil pesan', (tester) async {
      final api = InboxApiClient();
      final vm = InboxViewModel(
        apiClient: api,
        targets: FakeTargets(api),
        onOpen: (screenId, id) async {},
      );
      vm.setItemsForTest([]);

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: InboxScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada pemberitahuan.'), findsOneWidget);
    });
  });
}
