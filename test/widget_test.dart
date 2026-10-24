// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:my_project/main.dart';

void main() {
  testWidgets('chat screen shows the local assistant and starter prompts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Mola'), findsOneWidget);
    expect(find.text('Yerel asistan'), findsOneWidget);
    expect(find.text('Ollama model adı'), findsNothing);
    expect(find.textContaining('Aklında ne var?'), findsOneWidget);
    expect(find.text('Bana kısa bir hikaye yaz'), findsOneWidget);
  });
}
