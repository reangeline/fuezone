import 'package:flutter_test/flutter_test.dart';

import 'package:fuezone/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const FuezoneApp());
    expect(find.text('Fuezone'), findsOneWidget);
  });
}
