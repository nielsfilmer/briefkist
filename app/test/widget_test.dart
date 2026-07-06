// Smoke test: the app boots, both themes build, and the gallery renders the
// design-system widgets without exceptions.

import 'package:flutter_test/flutter_test.dart';
import 'package:my_flopy/main.dart';

void main() {
  testWidgets('gallery boots and renders', (tester) async {
    await tester.pumpWidget(const MyFlopyApp());
    await tester.pump();
    expect(find.text('my-flopy'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
