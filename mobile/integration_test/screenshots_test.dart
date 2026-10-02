// T42 evidence: capture REAL device screenshots of key screens for
// docs/evidence/android-uat.md. Uses the integration_test binding's
// takeScreenshot, written to disk by test_driver/integration_test.dart.
//
// Run: cd mobile && flutter drive \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/screenshots_test.dart -d <DEVICE_ID>

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/mobile_scenario.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture key screens on device', (tester) async {
    // Android requires the Flutter surface be an image before screenshots.
    await binding.convertFlutterSurfaceToImage();

    final s = await makeMobileScenario();
    await s.loginAsOperator();
    await s.enqueueDaily();

    for (final id in [
      'login',
      'today',
      'daily-form',
      'sync-center',
      'account',
    ]) {
      await tester.pumpWidget(s.appAt(id));
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot('t42-$id');
    }
  });
}
