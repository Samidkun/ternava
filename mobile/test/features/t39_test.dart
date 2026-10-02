import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/api/api_client.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/api/generated/types.dart';
import 'package:mobile/features/insights/home_screen.dart';
import 'package:mobile/features/insights/home_view_model.dart';
import 'package:mobile/features/insights/reports_screen.dart';
import 'package:mobile/features/insights/reports_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

class InsightsApiClient extends ApiClient {
  InsightsApiClient() : super(baseUrl: 'http://localhost');
  JsonObject? lastBody;
  JsonObject? lastQuery;
  String? lastOp;
  ApiFailure? throwNext;
  bool reportAllMissing = false;

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
    lastQuery = queryParams;
    final t = throwNext;
    if (t != null) {
      throwNext = null;
      throw t;
    }
    if (operationId == 'dashboard') {
      return {
        'data': {
          'business_date': '2026-10-02',
          'timezone': 'Asia/Jakarta',
          'as_of': '2026-10-02T06:00:00Z',
          'expected_records': 2,
          'accepted_records': 1,
          'eggs_count': 85,
          'feed_kg': '12.50',
          'open_incidents': 1,
          'low_stock_feed_type_ids': ['feed-1'],
          'cages': [
            {
              'cage_id': 'cage-1',
              'flock_id': 'flock-1',
              'business_date': '2026-10-02',
              'record_state': 'accepted',
              'eggs_count': 85,
              'feed_kg': '12.50',
            },
            {
              'cage_id': 'cage-2',
              'flock_id': 'flock-2',
              'business_date': '2026-10-02',
              'record_state': 'missing',
              'eggs_count': null,
              'feed_kg': null,
            },
          ],
        },
      };
    }
    if (operationId == 'operationsReport') {
      return {
        'data': {
          'from': '2026-10-01',
          'to': '2026-10-02',
          'timezone': 'Asia/Jakarta',
          'as_of': '2026-10-02T06:00:00Z',
          'expected_records': 2,
          'accepted_records': reportAllMissing ? 0 : 1,
          'eggs_count': reportAllMissing ? null : 85,
          'feed_kg': reportAllMissing ? null : '12.50',
          'rows': reportAllMissing
              ? [
                  {
                    'business_date': '2026-10-02',
                    'cage_id': 'cage-1',
                    'flock_id': 'flock-1',
                    'record_state': 'missing',
                    'eggs_count': null,
                    'feed_kg': null,
                    'mortality_count': null,
                    'condition': null,
                  },
                ]
              : [
                  {
                    'business_date': '2026-10-02',
                    'cage_id': 'cage-1',
                    'flock_id': 'flock-1',
                    'record_state': 'accepted',
                    'eggs_count': 85,
                    'feed_kg': '12.50',
                    'mortality_count': 0,
                    'condition': 'normal',
                  },
                ],
        },
      };
    }
    return {'data': {}};
  }
}

void main() {
  group('T39 Dashboard & Reports tests', () {
    testWidgets('report missing tidak menampilkan nol', (tester) async {
      final api = InsightsApiClient()..reportAllMissing = true;
      final vm = ReportsViewModel(apiClient: api);
      await vm.load('2026-10-01', '2026-10-02');

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: ReportsScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum dicatat'), findsWidgets);
    });

    testWidgets('report accepted menampilkan angka', (tester) async {
      final api = InsightsApiClient();
      final vm = ReportsViewModel(apiClient: api);
      await vm.load('2026-10-01', '2026-10-02');

      expect(vm.report, isNotNull);
      expect(vm.report!.eggsCount, 85);
    });

    testWidgets('periode lebih dari 183 hari ditolak', (tester) async {
      final api = InsightsApiClient();
      final vm = ReportsViewModel(apiClient: api);

      final ok = await vm.load('2026-01-01', '2026-12-31');

      expect(ok, isFalse);
      expect(vm.errorMessage, isNotNull);
      // The server must never be called for an invalid period.
      expect(api.lastOp, isNull);
    });

    testWidgets('export gagal mempertahankan filter', (tester) async {
      final api = InsightsApiClient();
      final vm = ReportsViewModel(apiClient: api);
      await vm.load('2026-10-01', '2026-10-02');

      api.throwNext = const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Ekspor gagal.',
        status: 0,
        retryable: true,
      );

      await vm.exportCsv();

      expect(vm.errorMessage, isNotNull);
      // Filters survive the failed export.
      expect(vm.from, '2026-10-01');
      expect(vm.to, '2026-10-02');
    });

    testWidgets('dashboard menampilkan status kelengkapan', (tester) async {
      final api = InsightsApiClient();
      final vm = HomeViewModel(apiClient: api);
      await vm.refresh('2026-10-02');

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      expect(vm.dashboard, isNotNull);
      expect(vm.dashboard!.acceptedRecords, 1);
      expect(vm.dashboard!.expectedRecords, 2);
    });

    testWidgets('dashboard missing tidak dirender sebagai nol', (tester) async {
      final api = InsightsApiClient();
      final vm = HomeViewModel(apiClient: api);
      await vm.refresh('2026-10-02');

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: HomeScreen(viewModel: vm),
        ),
      );
      await tester.pumpAndSettle();

      final missingCage = vm.dashboard!.cages.firstWhere(
        (c) => c.recordState == 'missing',
      );
      expect(missingCage.eggsCount, isNull);
      expect(find.text('Belum dicatat'), findsWidgets);
    });

    testWidgets('snapshot as_of ditampilkan', (tester) async {
      final api = InsightsApiClient();
      final vm = HomeViewModel(apiClient: api);
      await vm.refresh('2026-10-02');

      expect(vm.dashboard!.asOf, isNotEmpty);
      expect(vm.dashboard!.timezone, 'Asia/Jakarta');
    });

    testWidgets('dashboard gagal menyimpan snapshot lama', (tester) async {
      final api = InsightsApiClient();
      final vm = HomeViewModel(apiClient: api);
      await vm.refresh('2026-10-02');

      api.throwNext = const ApiFailure(
        code: 'NETWORK_ERROR',
        message: 'Offline.',
        status: 0,
        retryable: true,
      );
      await vm.refresh('2026-10-03');

      // The previous snapshot is retained and flagged as stale.
      expect(vm.dashboard, isNotNull);
      expect(vm.isStale, isTrue);
    });
  });
}
