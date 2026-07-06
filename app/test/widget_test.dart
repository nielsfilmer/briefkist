// Smoke test: the app boots with an unconfigured AppConfig, both themes
// build, and the shell renders without exceptions.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flopy/app_config.dart';
import 'package:my_flopy/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shell boots unconfigured', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final config = await AppConfig.load();
    await tester.pumpWidget(MyFlopyApp(config: config));
    await tester.pump();
    // Unconfigured: the shell must land on settings/pairing guidance.
    expect(find.textContaining('server'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
