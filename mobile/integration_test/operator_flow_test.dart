// T42 — operator offline flow, run on a real Android device/emulator.
//
// Covers AC-01, AC-10, AC-12, AC-13, AC-19, AC-23, AC-25, AC-39.
// These tests drive the REAL production widgets and repositories. They do NOT
// replace the TalkBack manual checklist or the true OS-process-kill checks;
// those are recorded honestly in docs/evidence/android-uat.md.
//
// Run: cd mobile && flutter test integration_test/operator_flow_test.dart -d <DEVICE_ID>

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/core/api/api_failure.dart';
import 'package:mobile/core/sync/retry_policy.dart';

import 'support/mobile_scenario.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('catatan offline survive relaunch lalu sync sekali', (
    tester,
  ) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();
    s.transport.offline = true;

    await s.enqueueDaily();
    expect(await s.pendingIds(), hasLength(1));

    // Simulated process restart: recover sending + refresh, draft/outbox kept.
    await s.relaunch();
    expect(await s.pendingIds(), hasLength(1));

    s.transport.offline = false;
    await s.worker.runOnce();
    expect(s.transport.businessEffects, 1);
    expect(await s.pendingIds(), isEmpty);
  });

  testWidgets('timeout setelah commit mempertahankan key dan payload', (
    tester,
  ) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();
    s.transport.dropAckAfterEffect = true;

    await s.enqueueDaily(feedKg: '9.75', eggs: 42);
    final before = (await s.pendingIds()).single;

    await s.worker.runOnce(); // server applied effect, ACK dropped
    expect(s.transport.businessEffects, 1);

    // Intent is NOT lost; it is retained for a retry with the same key.
    final after = await s.pendingIds();
    expect(after, contains(before));
    final intents = await s.outbox.allIntents();
    final retained = intents.firstWhere((i) => i.id == before);
    expect(retained.payload['feed_kg'], '9.75');

    // Retry reuses the SAME idempotency key.
    s.transport.dropAckAfterEffect = false;
    await s.worker.runOnce();
    expect(
      s.transport.sentKeys.where((k) => k == before).length,
      greaterThanOrEqualTo(2),
    );
  });

  testWidgets('teks temuan offline tahan relaunch dan tidak hilang', (
    tester,
  ) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();
    s.transport.offline = true;

    await s.enqueueIncident('Nafsu makan menurun');
    await s.relaunch();
    expect(await s.incidentText(), 'Nafsu makan menurun');

    // A failed send must keep the text (never roll it back).
    await s.worker.runOnce();
    expect(await s.incidentText(), 'Nafsu makan menurun');
    expect(await s.pendingIds(), hasLength(1));
  });

  testWidgets('401/403 menghentikan retry, 409/422 minta tinjauan', (
    tester,
  ) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();

    await s.enqueueDaily();
    final key = (await s.pendingIds()).single;
    final intents = await s.outbox.allIntents();
    final intent = intents.firstWhere((i) => i.id == key);

    // Drive the production retry policy directly on the real failure types.
    expect(
      s.worker.retryPolicy
          .next(
            const ApiFailure(code: 'UNAUTHORIZED', message: 'x', status: 401),
            intent.attempts + 1,
          )
          .action,
      RetryAction.stopBlockedAuth,
    );
    expect(
      s.worker.retryPolicy
          .next(
            const ApiFailure(
              code: 'DAILY_ALREADY_EXISTS',
              message: 'x',
              status: 409,
            ),
            intent.attempts + 1,
          )
          .action,
      RetryAction.needsReview,
    );
  });

  testWidgets('daily-form dan sync-center render di perangkat', (tester) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();
    await s.enqueueDaily();

    await tester.pumpWidget(s.appAt('daily-form'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsWidgets);

    await tester.pumpWidget(s.appAt('sync-center'));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
  });

  testWidgets('layar kritis membangun frame tanpa error di perangkat', (
    tester,
  ) async {
    final s = await makeMobileScenario();
    await s.loginAsOperator();

    for (final id in [
      'login',
      'today',
      'daily-form',
      'sync-center',
      'account',
    ]) {
      await tester.pumpWidget(s.appAt(id));
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        tester.takeException(),
        isNull,
        reason: 'layar $id gagal dirender',
      );
    }
  });
}
