// T42 evidence driver: runs integration_test/screenshots_test.dart on a real
// device and writes the PNGs that the test requests via `takeScreenshot`.
//
// Run: cd mobile && flutter drive \
//   --driver=test_driver/integration_test.dart \
//   --target=integration_test/screenshots_test.dart -d <DEVICE_ID>

import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final outDir = Directory('build/uat-screenshots');
  if (!outDir.existsSync()) {
    outDir.createSync(recursive: true);
  }
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('${outDir.path}/$name.png');
      file.writeAsBytesSync(bytes);
      stdout.writeln('saved ${file.path}');
      return true;
    },
  );
}
