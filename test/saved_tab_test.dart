import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sportsense/main.dart';
import 'package:sportsense/services/vector_db_manager.dart';
import 'package:sportsense/services/user_query_vectorizer.dart';
import 'package:sportsense/services/uefa_parser.dart';
import 'package:sportsense/services/qwen_api_service.dart';
import 'package:sportsense/services/rankings_vector_search.dart';
import 'package:sportsense/services/database_service.dart';
import 'package:sportsense/services/database_models.dart';

void main() {
  group('SavedTab Tests', () {
    testWidgets('SavedTab shows login prompt when user is not logged in',
        (WidgetTester tester) async {
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

      // Переключаемся на вкладку "Сохраненное" (индекс 3)
      final navItems = find.byType(InkWell);
      // Ищем элемент с текстом "Сохраненное" или "Saved"
      final savedTabText = find.text('Сохраненное');
      if (savedTabText.evaluate().isNotEmpty) {
        await tester.tap(savedTabText);
      } else {
        final savedTabTextEn = find.text('Saved');
        if (savedTabTextEn.evaluate().isNotEmpty) {
          await tester.tap(savedTabTextEn);
        }
      }

      await tester.pumpAndSettle();

      // Проверяем что показывается сообщение о необходимости входа
      expect(
        find.text(
          'Войдите в аккаунт, чтобы сохранять клубы, игроков и мониторинги.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('SavedTab shows empty state when no items saved',
        (WidgetTester tester) async {
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

      // Переключаемся на вкладку "Сохраненное"
      final savedTabText = find.text('Сохраненное');
      if (savedTabText.evaluate().isNotEmpty) {
        await tester.tap(savedTabText);
        await tester.pumpAndSettle();
      }

      // Проверяем что показывается empty state
      expect(find.text('Пока ничего не сохранено'), findsOneWidget);
      expect(
        find.text('Сохраняйте клубы, игроков и мониторинги для быстрого доступа'),
        findsOneWidget,
      );
    });
  });

  group('DatabaseService SavedItem Tests', () {
    late DatabaseServiceNative dbService;

    setUp(() {
      dbService = DatabaseServiceNative();
    });

    tearDown(() {
      dbService.clear();
    });

    test('saveItem saves and retrieves item', () async {
      // Регистрируем пользователя
      final user = await dbService.registerUser(
        name: 'Test User',
        email: 'test@example.com',
        password: 'password123',
      );

      expect(user, isNotNull);
      expect(user!.id, isNotNull);

      // Сохраняем элемент
      final savedItem = await dbService.saveItem(
        userId: user.id!,
        title: 'Manchester United',
        subtitle: 'Club form tracking',
        type: 'club',
        metadata: '{"league": "Premier League"}',
      );

      expect(savedItem, isNotNull);
      expect(savedItem!.id, isNotNull);
      expect(savedItem.title, equals('Manchester United'));
      expect(savedItem.type, equals('club'));

      // Получаем сохраненные элементы
      final items = await dbService.getUserSavedItems(user.id!);

      expect(items.length, equals(1));
      expect(items[0].title, equals('Manchester United'));
      expect(items[0].subtitle, equals('Club form tracking'));
    });

    test('saveItem saves multiple items and retrieves all', () async {
      final user = await dbService.registerUser(
        name: 'Test User',
        email: 'test2@example.com',
        password: 'password123',
      );

      expect(user, isNotNull);

      // Сохраняем несколько элементов
      await dbService.saveItem(
        userId: user!.id!,
        title: 'Manchester City',
        subtitle: 'Club brief',
        type: 'club',
      );

      await dbService.saveItem(
        userId: user.id!,
        title: 'Erling Haaland',
        subtitle: 'Player radar',
        type: 'player',
      );

      await dbService.saveItem(
        userId: user.id!,
        title: 'UEFA Rankings',
        subtitle: 'Weekly monitor',
        type: 'monitor',
      );

      final items = await dbService.getUserSavedItems(user.id!);

      expect(items.length, equals(3));
      // Проверяем сортировку по дате (новые первыми)
      expect(items[0].title, equals('UEFA Rankings'));
      expect(items[1].title, equals('Erling Haaland'));
      expect(items[2].title, equals('Manchester City'));
    });

    test('deleteSavedItem removes item', () async {
      final user = await dbService.registerUser(
        name: 'Test User',
        email: 'test3@example.com',
        password: 'password123',
      );

      expect(user, isNotNull);

      final item = await dbService.saveItem(
        userId: user!.id!,
        title: 'Item to Delete',
        subtitle: 'Will be removed',
        type: 'club',
      );

      expect(item, isNotNull);
      expect(item!.id, isNotNull);

      // Проверяем что элемент есть
      var items = await dbService.getUserSavedItems(user.id!);
      expect(items.length, equals(1));

      // Удаляем элемент
      await dbService.deleteSavedItem(item.id!);

      // Проверяем что элемент удален
      items = await dbService.getUserSavedItems(user.id!);
      expect(items.length, equals(0));
    });

    test('getUserSavedItems returns empty for user with no items', () async {
      final user = await dbService.registerUser(
        name: 'Test User',
        email: 'test4@example.com',
        password: 'password123',
      );

      expect(user, isNotNull);

      final items = await dbService.getUserSavedItems(user!.id!);

      expect(items, isEmpty);
    });

    test('saveItem handles different types correctly', () async {
      final user = await dbService.registerUser(
        name: 'Test User',
        email: 'test5@example.com',
        password: 'password123',
      );

      expect(user, isNotNull);

      final clubItem = await dbService.saveItem(
        userId: user!.id!,
        title: 'Liverpool',
        subtitle: 'Club',
        type: 'club',
      );

      final playerItem = await dbService.saveItem(
        userId: user.id!,
        title: 'Mohamed Salah',
        subtitle: 'Player',
        type: 'player',
      );

      final monitorItem = await dbService.saveItem(
        userId: user.id!,
        title: 'Champions League Tracker',
        subtitle: 'Monitor',
        type: 'monitor',
      );

      expect(clubItem!.type, equals('club'));
      expect(playerItem!.type, equals('player'));
      expect(monitorItem!.type, equals('monitor'));
    });

    test('SavedItem copyWith works correctly', () async {
      final original = SavedItem(
        id: 1,
        userId: 1,
        title: 'Original Title',
        subtitle: 'Original Subtitle',
        type: 'club',
        createdAt: DateTime.now(),
      );

      final copied = original.copyWith(title: 'New Title');

      expect(copied.title, equals('New Title'));
      expect(copied.subtitle, equals('Original Subtitle'));
      expect(copied.type, equals('club'));
      expect(copied.id, equals(1));
    });

    test('SavedItem toMap and fromMap work correctly', () async {
      final now = DateTime.now();
      final item = SavedItem(
        id: 1,
        userId: 1,
        title: 'Test Item',
        subtitle: 'Test Subtitle',
        type: 'player',
        metadata: '{"stats": {"goals": 10}}',
        createdAt: now,
      );

      final map = item.toMap();
      final restored = SavedItem.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.userId, equals(1));
      expect(restored.title, equals('Test Item'));
      expect(restored.subtitle, equals('Test Subtitle'));
      expect(restored.type, equals('player'));
      expect(restored.metadata, equals('{"stats": {"goals": 10}}'));
    });
  });
}
