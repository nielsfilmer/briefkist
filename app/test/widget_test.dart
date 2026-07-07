// Smoke test: the app boots with an unconfigured AppConfig, both themes
// build, and the shell renders without exceptions.

import 'package:flutter_test/flutter_test.dart';
import 'package:briefkist/app_config.dart';
import 'package:briefkist/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shell boots unconfigured', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final config = await AppConfig.load();
    await tester.pumpWidget(MyFlopyApp(config: config));
    await tester.pump();
    // Which shell renders depends on the host platform (a macOS test runner
    // boots the desktop shell); unconfigured, both land on settings, which
    // has exactly one Save button.
    expect(find.text('Save'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
