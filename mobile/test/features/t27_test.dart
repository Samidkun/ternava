import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/features/access/member_form_screen.dart';
import 'package:mobile/features/access/member_form_view_model.dart';
import 'package:mobile/features/access/team_list_screen.dart';
import 'package:mobile/features/access/team_list_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class MemberApiClient extends ApiClient {
  MemberApiClient() : super(baseUrl: 'http://localhost');
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
    return {
      'data': {'id': 'member-1', 'username': body?['username']},
    };
  }
}

void main() {
  group('T27 Team & member form tests', () {
    testWidgets('password sementara tidak diprefill', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = MemberFormViewModel(
        apiClient: MemberApiClient(),
        outbox: outbox,
        role: 'owner',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: MemberFormScreen(viewModel: viewModel),
        ),
      );

      final field = tester.widget<TextField>(
        find.byKey(const Key('temporary-password')),
      );
      expect(field.controller!.text, isEmpty);
    });

    testWidgets('admin hanya bisa memilih peran operator', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'admin-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = MemberFormViewModel(
        apiClient: MemberApiClient(),
        outbox: outbox,
        role: 'admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: MemberFormScreen(viewModel: viewModel),
        ),
      );

      // Only "operator" role option is available to admins.
      expect(viewModel.assignableRoles, ['operator']);
      expect(find.text('Operator'), findsWidgets);
      expect(find.text('Admin'), findsNothing);
      expect(find.text('Owner'), findsNothing);
    });

    testWidgets('payload password tidak pernah disimpan lokal', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = MemberApiClient();
      api.throwNext = const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Koneksi terputus.',
        status: 0,
        retryable: true,
      );
      final viewModel = MemberFormViewModel(
        apiClient: api,
        outbox: outbox,
        role: 'owner',
      );

      await viewModel.create({
        'username': 'operator_budi',
        'display_name': 'Budi',
        'role': 'operator',
        'temporary_password': 'rahasia12345',
      });

      // No local intent may contain the password.
      final intents = await outbox.allIntents();
      for (final intent in intents) {
        expect(intent.payload.containsKey('temporary_password'), isFalse);
      }
    });

    testWidgets('password minimal 12 karakter ditolak', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = MemberFormViewModel(
        apiClient: MemberApiClient(),
        outbox: outbox,
        role: 'owner',
      );

      final ok = await viewModel.create({
        'username': 'operator_budi',
        'display_name': 'Budi',
        'role': 'operator',
        'temporary_password': 'pendek123',
      });

      expect(ok, isFalse);
      expect(viewModel.errorMessage, contains('12'));
    });

    testWidgets('daftar tim memuat anggota', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = MemberApiClient();
      final viewModel = TeamListViewModel(apiClient: api, outbox: outbox);
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: TeamListScreen(viewModel: viewModel),
        ),
      );

      expect(find.text('Tim Peternakan'), findsOneWidget);
    });
  });
}
