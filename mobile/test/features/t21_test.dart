import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/bootstrap_coordinator.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart';
import 'package:mobile/features/access/login_screen.dart';
import 'package:mobile/features/access/login_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

void main() {
  group('T21 Login & Account screen tests', () {
    testWidgets(
      'login offline pertama kali menampilkan pesan pemulihan yang jelas',
      (tester) async {
        final store = PartitionStore();
        final outbox = OutboxRepository(store: store);
        final cache = CacheRepository(store: store);
        final coordinator = BootstrapCoordinator(
          cache: cache,
          outbox: outbox,
          transport: DummySyncTransport(),
        );

        final failingClient = MockFailingApiClient(
          failure: const ApiFailure(
            code: 'NETWORK_ERROR',
            message: 'Tidak dapat terhubung ke server',
            status: 0,
            retryable: true,
          ),
        );

        final viewModel = LoginViewModel(
          apiClient: failingClient,
          coordinator: coordinator,
          store: store,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: TernavaTheme.light(),
            home: LoginScreen(viewModel: viewModel),
          ),
        );

        expect(find.text('Masuk ke TERNAVA'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('username-input')),
          'operator_budi',
        );
        await tester.enterText(
          find.byKey(const Key('password-input')),
          'password123',
        );

        await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
        await tester.pumpAndSettle();

        expect(
          find.text('Sambungkan internet untuk masuk pertama kali.'),
          findsOneWidget,
        );
      },
    );
  });
}

class DummySyncTransport implements SyncTransport {
  @override
  Future<List<Map<String, Object?>>> fetchAllBootstrapPages() async => [];
}

class MockFailingApiClient extends ApiClient {
  final ApiFailure failure;

  MockFailingApiClient({required this.failure})
    : super(baseUrl: 'http://localhost');

  @override
  Future<Map<String, Object?>> request(
    String operationId, {
    Map<String, String>? pathParams,
    Map<String, String>? queryParams,
    Map<String, Object?>? body,
    String? idempotencyKey,
  }) async {
    throw failure;
  }
}
