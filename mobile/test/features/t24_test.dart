import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/core/sync/retry_policy.dart';
import 'package:mobile/core/sync/sync_worker.dart';
import 'package:mobile/features/access/farm_setup_screen.dart';
import 'package:mobile/features/access/farm_setup_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class RejectOnceTransport implements Transport {
  ApiFailure? _next;
  JsonObject lastBody = const {};
  String? lastKey;

  void rejectNext(String code, int status) {
    _next = ApiFailure(
      code: code,
      message: 'Zona waktu tidak valid.',
      status: status,
      retryable: false,
    );
  }

  @override
  Future<JsonObject> send(
    String operationId,
    JsonObject payload,
    String idempotencyKey,
  ) async {
    lastBody = payload;
    lastKey = idempotencyKey;
    final rejection = _next;
    if (rejection != null) {
      _next = null;
      throw rejection;
    }
    return {'status': 'accepted'};
  }
}

class FakeApiClient extends ApiClient {
  FakeApiClient() : super(baseUrl: 'http://localhost');
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
      'data': {'id': 'farm-1', ...?body},
    };
  }
}

void main() {
  group('T24 Farm setup tests', () {
    testWidgets('zona ditolak mempertahankan isian', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final transport = RejectOnceTransport();
      final worker = SyncWorker(
        outbox: outbox,
        transport: transport,
        retryPolicy: const RetryPolicy(),
      );
      final api = FakeApiClient();
      api.throwNext = const ApiFailure(
        code: 'VALIDATION_FAILED',
        message: 'Zona waktu tidak valid.',
        status: 422,
        retryable: false,
      );

      final viewModel = FarmSetupViewModel(
        apiClient: api,
        outbox: outbox,
        worker: worker,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FarmSetupScreen(viewModel: viewModel),
        ),
      );

      await tester.enterText(find.byKey(const Key('farm-name')), 'Farm Uji');
      await tester.tap(find.text('Simpan peternakan'));
      await tester.pumpAndSettle();

      // Field value preserved after rejection
      expect(find.text('Farm Uji'), findsOneWidget);
    });

    testWidgets('form awal tidak memuat isian fiktif', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final transport = RejectOnceTransport();
      final worker = SyncWorker(
        outbox: outbox,
        transport: transport,
        retryPolicy: const RetryPolicy(),
      );
      final viewModel = FarmSetupViewModel(
        apiClient: FakeApiClient(),
        outbox: outbox,
        worker: worker,
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FarmSetupScreen(viewModel: viewModel),
        ),
      );

      final nameField = tester.widget<TextField>(
        find.byKey(const Key('farm-name')),
      );
      expect(nameField.controller!.text, isEmpty);
    });

    test(
      'respons tidak diketahui menyimpan key/payload untuk diulang',
      () async {
        final store = PartitionStore();
        await store.unlock(
          const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
        );
        final outbox = outbox_lib.OutboxRepository(store: store);
        final transport = RejectOnceTransport();
        final worker = SyncWorker(
          outbox: outbox,
          transport: transport,
          retryPolicy: const RetryPolicy(),
        );
        final api = FakeApiClient();
        api.throwNext = const ApiFailure(
          code: 'NETWORK_ERROR',
          message: 'Koneksi terputus.',
          status: 0,
          retryable: true,
        );

        final viewModel = FarmSetupViewModel(
          apiClient: api,
          outbox: outbox,
          worker: worker,
        );

        final key = viewModel.ensurePersistKey();
        await viewModel.save({
          'name': 'Farm Uji',
          'location': 'Blitar',
          'timezone': 'Asia/Jakarta',
        });

        // Persist key must be stable across attempts
        expect(viewModel.ensurePersistKey(), key);

        final intents = await outbox.allIntents();
        expect(intents, hasLength(1));
        expect(intents.first.id, key);
        expect(intents.first.payload['name'], 'Farm Uji');
      },
    );
  });
}
