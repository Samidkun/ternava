import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/local/partition_store.dart';
import 'package:mobile/core/sync/cache_repository.dart';
import 'package:mobile/core/sync/outbox_repository.dart';
import 'package:mobile/features/daily/daily_form_screen.dart';
import 'package:mobile/features/daily/daily_form_view_model.dart';
import 'package:mobile/features/daily/today_screen.dart';
import 'package:mobile/features/daily/today_view_model.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

void main() {
  group('T22 Today & Daily Form tests', () {
    testWidgets(
      'pakan kosong tidak menjadi nol dan menampilkan pesan validasi',
      (tester) async {
        final store = PartitionStore();
        await store.unlock(
          const PartitionId(actorId: 'act-1', farmId: 'farm-1'),
        );
        final outbox = OutboxRepository(store: store);

        final viewModel = DailyFormViewModel(
          outbox: outbox,
          flockId: 'flock-123',
          cageName: 'Kandang 1',
          businessDate: '2026-10-01',
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: TernavaTheme.light(),
            home: DailyFormScreen(viewModel: viewModel),
          ),
        );

        // Attempt to submit with empty feed_kg
        await tester.tap(find.widgetWithText(FilledButton, 'Kirim Catatan'));
        await tester.pumpAndSettle();

        final pending = await outbox.pendingIntents();
        expect(pending, isEmpty); // Outbox must be empty!
        expect(find.text('Isi jumlah pakan dalam kg.'), findsOneWidget);
      },
    );

    testWidgets('Today screen lists assigned cages and recording status', (
      tester,
    ) async {
      final store = PartitionStore();
      await store.unlock(const PartitionId(actorId: 'act-1', farmId: 'farm-1'));
      final cache = CacheRepository(store: store);
      await cache.applyPage({
        'scope_version': 1,
        'as_of': '2026-10-01T08:00:00Z',
        'changes': [
          {
            'resource_type': 'cage',
            'resource_id': 'c-1',
            'action': 'upsert',
            'value': {'id': 'c-1', 'name': 'Kandang Baterai A', 'code': 'K-01'},
          },
        ],
        'next_cursor': null,
        'has_more': false,
      });

      final viewModel = TodayViewModel(cache: cache);
      await viewModel.load();

      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: TodayScreen(viewModel: viewModel),
        ),
      );

      expect(find.text('Tugas Hari Ini'), findsOneWidget);
      expect(find.text('Kandang Baterai A'), findsOneWidget);
      expect(find.text('Belum dicatat'), findsOneWidget);
    });
  });
}
