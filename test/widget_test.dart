import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:esso/main.dart';

void main() {
  testWidgets('Inkora AI launches successfully', (
      WidgetTester tester,
      ) async {
    await tester.pumpWidget(
      const InkoraApp(
        initialThemeMode: ThemeMode.light,
      ),
    );

    expect(find.text('Inkora AI'), findsOneWidget);
    expect(
      find.text('Your handwritten notes. Smarter evaluation.'),
      findsOneWidget,
    );
  });
}