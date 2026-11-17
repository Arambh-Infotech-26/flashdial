// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:flashdial/main.dart';

void main() {
  testWidgets('renders the FlashDial dial pad', (WidgetTester tester) async {
    await tester.pumpWidget(const FlashDialApp());

    expect(find.text('FlashDial'), findsOneWidget);
    expect(find.text('Enter a number'), findsOneWidget);
    expect(find.bySemanticsLabel('Call number'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
  });
}
