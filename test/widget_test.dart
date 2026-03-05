import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsense/main.dart';

void main() {
  testWidgets('SpaceApp renders correctly', (WidgetTester tester) async {
    // Запускаем приложение
    await tester.pumpWidget(const SpaceApp());

    // Проверяем что заголовок отображается
    expect(find.text('TEST APP'), findsOneWidget);
    expect(find.text('Welcome to the Future'), findsOneWidget);
    
    // Проверяем что карточка с контентом отображается
    expect(find.text('Ready to Explore'), findsOneWidget);
    expect(find.text('Launch Mission'), findsOneWidget);
    
    // Проверяем что иконка ракеты есть
    expect(find.byIcon(Icons.rocket_launch_rounded), findsOneWidget);
  });

  testWidgets('Launch Mission button shows snackbar', (WidgetTester tester) async {
    // Запускаем приложение
    await tester.pumpWidget(const SpaceApp());

    // Проверяем что изначально SnackBar нет
    expect(find.text('Launching into space... 🚀'), findsNothing);

    // Нажимаем кнопку Launch Mission
    await tester.tap(find.text('Launch Mission'));
    await tester.pump();

    // Проверяем что SnackBar появился
    expect(find.text('Launching into space... 🚀'), findsOneWidget);
  });

  testWidgets('Description text is visible', (WidgetTester tester) async {
    await tester.pumpWidget(const SpaceApp());

    // Проверяем что описание видно
    expect(find.textContaining('Your journey through the digital universe'), findsOneWidget);
  });
}
