import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() async {
  final driver = await FlutterDriver.connect();
  await integrationDriver(
    driver: driver,
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('/Users/omid/code/walletops/demos/screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes);
      stdout.writeln('Wrote screenshot ${file.path}');
      return true;
    },
  );
}
