import 'package:flutter_test/flutter_test.dart';

import 'package:amcha_ai_dot_com/main.dart';

void main() {
  testWidgets('App renders chat shell', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('ISG Assist'), findsOneWidget);
    expect(find.text('Type your message...'), findsOneWidget);
  });
}
