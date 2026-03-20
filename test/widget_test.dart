import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsense/main.dart';
import 'package:sportsense/services/core/vector_db_manager.dart';
import 'package:sportsense/services/core/user_query_vectorizer.dart';
import 'package:sportsense/services/core/uefa_parser.dart';
import 'package:sportsense/services/api/qwen_api_service.dart';
import 'package:sportsense/services/core/rankings_vector_search.dart';

void main() {
  testWidgets('SpaceApp renders correctly', (WidgetTester tester) async {
    final vectorDbManager = VectorDatabaseManager();
    final queryVectorizer = UserQueryVectorizerService(
      dbManager: vectorDbManager,
    );
    final uefaParser = UefaParser(vectorDbManager: vectorDbManager);
    final qwenApi = QwenApiService();
    final rankingsSearch = RankingsVectorSearch(dbManager: vectorDbManager);

    await tester.pumpWidget(
      SpaceApp(
        vectorDbManager: vectorDbManager,
        queryVectorizer: queryVectorizer,
        uefaParser: uefaParser,
        qwenApi: qwenApi,
        rankingsSearch: rankingsSearch,
        rankingsApiAvailable: false,
        qwenAvailable: false,
      ),
    );

    // Проверяем заголовок
    expect(find.text('Sportsense'), findsOneWidget);
    expect(find.text('AI-Powered Assistant'), findsOneWidget);
  });

  testWidgets('Chat interface has input field', (WidgetTester tester) async {
    final vectorDbManager = VectorDatabaseManager();
    final queryVectorizer = UserQueryVectorizerService(
      dbManager: vectorDbManager,
    );
    final uefaParser = UefaParser(vectorDbManager: vectorDbManager);
    final qwenApi = QwenApiService();
    final rankingsSearch = RankingsVectorSearch(dbManager: vectorDbManager);

    await tester.pumpWidget(
      SpaceApp(
        vectorDbManager: vectorDbManager,
        queryVectorizer: queryVectorizer,
        uefaParser: uefaParser,
        qwenApi: qwenApi,
        rankingsSearch: rankingsSearch,
        rankingsApiAvailable: false,
        qwenAvailable: false,
      ),
    );

    // Проверяем что поле ввода есть
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('Send button is visible', (WidgetTester tester) async {
    final vectorDbManager = VectorDatabaseManager();
    final queryVectorizer = UserQueryVectorizerService(
      dbManager: vectorDbManager,
    );
    final uefaParser = UefaParser(vectorDbManager: vectorDbManager);
    final qwenApi = QwenApiService();
    final rankingsSearch = RankingsVectorSearch(dbManager: vectorDbManager);

    await tester.pumpWidget(
      SpaceApp(
        vectorDbManager: vectorDbManager,
        queryVectorizer: queryVectorizer,
        uefaParser: uefaParser,
        qwenApi: qwenApi,
        rankingsSearch: rankingsSearch,
        rankingsApiAvailable: false,
        qwenAvailable: false,
      ),
    );

    // Проверяем что кнопка отправки есть
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}
