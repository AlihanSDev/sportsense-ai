import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsense/main.dart';

void main() {
  testWidgets('SpaceApp renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SpaceApp());

    // Проверяем заголовок
    expect(find.text('Sportsense'), findsOneWidget);
    expect(find.text('AI-Powered Assistant'), findsOneWidget);
  });

  testWidgets('Chat interface has input field', (WidgetTester tester) async {
    await tester.pumpWidget(const SpaceApp());

    // Проверяем что поле ввода есть
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Send button is visible', (WidgetTester tester) async {
    await tester.pumpWidget(const SpaceApp());

    // Проверяем что кнопка отправки есть
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
