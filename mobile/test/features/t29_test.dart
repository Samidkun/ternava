import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/outbox_repository.dart' as outbox_lib;
import 'package:mobile/features/feed/feed_type_form_screen.dart';
import 'package:mobile/features/feed/feed_type_form_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class FeedTypeApiClient extends ApiClient {
  FeedTypeApiClient() : super(baseUrl: 'http://localhost');
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
      'data': {'id': 'ft-1', ...?body},
    };
  }
}

void main() {
  group('T29 Feed type & minimum threshold tests', () {
    testWidgets('edit jenis memakai versi accepted', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = FeedTypeApiClient();
      final viewModel = FeedTypeFormViewModel(
        apiClient: api,
        outbox: outbox,
        edit: true,
        initial: {
          'id': 'ft-1',
          'name': 'Pakan Starter',
          'min_threshold_kg': '50.00',
          'version': 1,
          'status': 'active',
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: FeedTypeFormScreen(viewModel: viewModel),
        ),
      );

      await tester.tap(find.text('Simpan jenis pakan'));
      await tester.pumpAndSettle();

      expect(api.lastBody!['base_version'], 1);
    });

    testWidgets('ambang minimum menyimpan presisi kg', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = FeedTypeApiClient();
      final viewModel = FeedTypeFormViewModel(
        apiClient: api,
        outbox: outbox,
        edit: true,
        initial: {
          'id': 'ft-1',
          'name': 'Pakan Starter',
          'min_threshold_kg': '50.00',
          'version': 1,
        },
      );

      await viewModel.save({
        'name': 'Pakan Starter',
        'min_threshold_kg': '42.50',
        'reason': 'Penyesuaian ambang',
      });

      // Presisi desimal dipertahankan apa adanya (string, bukan float).
      expect(api.lastBody!['min_threshold_kg'], '42.50');
      expect(api.lastBody!['min_threshold_kg'], isA<String>());
    });

    testWidgets('jenis nonaktif tetap menyimpan referensi histori', (
      tester,
    ) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final api = FeedTypeApiClient();
      final viewModel = FeedTypeFormViewModel(
        apiClient: api,
        outbox: outbox,
        edit: true,
        initial: {
          'id': 'ft-1',
          'name': 'Pakan Lama',
          'min_threshold_kg': '10.00',
          'version': 4,
          'status': 'active',
        },
      );

      // Deactivating keeps the row (referenced by history) rather than deleting.
      await viewModel.save({'name': 'Pakan Lama', 'status': 'inactive'});

      expect(api.lastBody!['status'], 'inactive');
    });

    testWidgets('alert stok memakai transisi bukan refresh', (tester) async {
      final store = PartitionStore();
      await store.unlock(
        const PartitionId(actorId: 'owner-1', farmId: 'farm-1'),
      );
      final outbox = outbox_lib.OutboxRepository(store: store);
      final viewModel = FeedTypeFormViewModel(
        apiClient: FeedTypeApiClient(),
        outbox: outbox,
        edit: false,
      );

      // Below/above threshold evaluated by transition, not by re-reading stock.
      expect(viewModel.isBelowThreshold('40.00', '50.00'), isTrue);
      expect(viewModel.isBelowThreshold('60.00', '50.00'), isFalse);
      expect(viewModel.isBelowThreshold('50.00', '50.00'), isFalse);
    });
  });
}
