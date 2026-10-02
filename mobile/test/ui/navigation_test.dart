import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/ui/components/status_panel.dart';
import 'package:mobile/ui/theme/ternava_theme.dart';

void main() {
  group('Theme & StatusPanel UI tests', () {
    testWidgets(
      'Ternava theme enforces 48dp minimum button size and primary color',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: TernavaTheme.light(),
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) {
                    final style = Theme.of(context).filledButtonTheme.style;
                    expect(style?.minimumSize?.resolve({}), const Size(48, 48));

                    return FilledButton(
                      onPressed: () {},
                      child: const Text('Simpan'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        final size = tester.getSize(find.byType(FilledButton));
        expect(size.height, greaterThanOrEqualTo(48.0));
        expect(size.width, greaterThanOrEqualTo(48.0));
        expect(find.text('Simpan'), findsOneWidget);
      },
    );

    testWidgets('StatusPanel displays text label and icon, not color alone', (
      tester,
    ) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: TernavaTheme.light(),
          home: Scaffold(
            body: StatusPanel(
              kind: StatusKind.offline,
              label: 'Mode Offline (Tersimpan Lokal)',
              asOf: '10:30 WIB',
              onRetry: () {
                retried = true;
              },
            ),
          ),
        ),
      );

      expect(find.text('Mode Offline (Tersimpan Lokal)'), findsOneWidget);
      expect(find.text('10:30 WIB'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);

      await tester.tap(find.text('Coba Lagi'));
      expect(retried, true);
    });
  });

  group('Navigation & dirty form PopScope test', () {
    testWidgets(
      'back does not discard input when user cancels back navigation',
      (tester) async {
        final controller = TextEditingController(text: '12.50');

        await tester.pumpWidget(
          MaterialApp(
            theme: TernavaTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/daily-form');
                    },
                    child: const Text('Open'),
                  );
                },
              ),
            ),
            routes: {
              '/daily-form': (context) => PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) async {
                  if (didPop) return;
                  final shouldLeave = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Batalkan perubahan?'),
                      content: const Text(
                        'Isian yang belum disimpan akan hilang.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('Tetap mengisi'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Buang'),
                        ),
                      ],
                    ),
                  );
                  if (shouldLeave == true && context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
                child: Scaffold(
                  appBar: AppBar(title: const Text('Catatan Harian')),
                  body: Form(
                    child: Column(
                      children: [
                        TextField(
                          key: const Key('feed-kg'),
                          controller: controller,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            },
          ),
        );

        // Tap to open daily form
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Catatan Harian'), findsOneWidget);
        expect(find.text('12.50'), findsOneWidget);

        // Attempt back navigation
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.maybePop();
        await tester.pumpAndSettle();

        // Confirm dialog appeared
        expect(find.text('Batalkan perubahan?'), findsOneWidget);
        expect(find.text('Tetap mengisi'), findsOneWidget);

        // Tap 'Tetap mengisi'
        await tester.tap(find.text('Tetap mengisi'));
        await tester.pumpAndSettle();

        // Input is preserved!
        expect(find.text('12.50'), findsOneWidget);
      },
    );
  });
}
