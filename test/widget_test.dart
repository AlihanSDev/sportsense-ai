import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsense/main.dart';

void main() {
  testWidgets('TestApp renders correctly', (WidgetTester tester) async {
    // Запускаем приложение
    await tester.pumpWidget(const TestApp());

    // Проверяем что заголовок отображается
    expect(find.text('TEST APP'), findsOneWidget);
    expect(find.text('Welcome to your new app'), findsOneWidget);
    
    // Проверяем что карточка с контентом отображается
    expect(find.text('Ready to Build'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    
    // Проверяем что иконка ракеты есть
    expect(find.byIcon(Icons.rocket_launch), findsOneWidget);
  });

  testWidgets('Get Started button shows snackbar', (WidgetTester tester) async {
    // Запускаем приложение
    await tester.pumpWidget(const TestApp());

    // Проверяем что изначально SnackBar нет
    expect(find.text('Button pressed! 🚀'), findsNothing);

    // Нажимаем кнопку Get Started
    await tester.tap(find.text('Get Started'));
    await tester.pump();

    // Проверяем что SnackBar появился
    expect(find.text('Button pressed! 🚀'), findsOneWidget);
  });

  testWidgets('Gradient background exists', (WidgetTester tester) async {
    await tester.pumpWidget(const TestApp());

    // Проверяем что градиентный контейнер есть
    expect(find.byType(Container), findsWidgets);
  });
}
