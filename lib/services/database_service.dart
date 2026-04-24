import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;

// Импортируем модели и интерфейс
import 'database_models.dart';

// Импортируем Supabase реализацию
import 'database_service_supabase.dart';

/// Инициализация базы данных для разных платформ
Future<void> initDatabase() async {
  // Для веба и нативных платформ используем Supabase
  print('Инициализация Supabase базы данных');

  // ВАЖНО: Перед запуском приложения выполните миграцию в Supabase SQL Editor:
  // 1. Откройте https://app.supabase.com/project/<your-project>/sql
  // 2. Выполните команды из файла: supabase/schema_custom_auth_fixed.sql
  // Это исправит sequences, отключит RLS и настроит таблицы правильно.

  // Для автоматической проверки можно добавить вызов health check, но пока пропустим.
}

/// Сервис для работы с базой данных (платформо-зависимый)
/// Это обёртка, которая делегирует вызовы к конкретной реализации

/// Сервис для работы с базой данных (платформо-зависимый)
/// Это обёртка, которая делегирует вызовы к конкретной реализации
class DatabaseService implements DatabaseServiceInterface {
  static DatabaseServiceInterface? _instance;

  /// Получить экземпляр сервиса (фабричный метод)
  factory DatabaseService() {
    if (_instance == null) {
      // Используем Supabase для всех платформ
      final supabase = Supabase.instance.client;
      _instance = DatabaseServiceSupabase(supabase);
    }
    // Возвращаем обёртку, которая делегирует вызовы
    return DatabaseService._(_instance!);
  }

  final DatabaseServiceInterface _delegate;

  /// Приватный конструктор
  DatabaseService._(this._delegate);

  @override
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
  }) => _delegate.registerUser(name: name, email: email, password: password);

  @override
  Future<User?> loginUser({required String email, required String password}) =>
      _delegate.loginUser(email: email, password: password);

  @override
  Future<bool> userExists(String email) => _delegate.userExists(email);

  @override
  Future<User?> getCurrentUser() => _delegate.getCurrentUser();

  @override
  Future<User?> getUserById(int userId) => _delegate.getUserById(userId);

  @override
  Future<void> logout() => _delegate.logout();

  @override
  Future<ChatSessionDB?> createChat({
    required int userId,
    required String title,
  }) => _delegate.createChat(userId: userId, title: title);

  @override
  Future<List<ChatSessionDB>> getUserChats(int userId) =>
      _delegate.getUserChats(userId);

  @override
  Future<void> deleteChat(int chatId) => _delegate.deleteChat(chatId);

  @override
  Future<ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  }) => _delegate.addMessage(chatId: chatId, text: text, isUser: isUser);

  @override
  Future<List<ChatMessageDB>> getChatMessages(int chatId) =>
      _delegate.getChatMessages(chatId);

  @override
  Future<void> clearChatMessages(int chatId) =>
      _delegate.clearChatMessages(chatId);

  @override
  Future<bool> updateChatTitle({required int chatId, required String title}) =>
      _delegate.updateChatTitle(chatId: chatId, title: title);

  @override
  Future<SavedItem?> saveItem({
    required int userId,
    required String title,
    required String subtitle,
    required String type,
    String? metadata,
  }) => _delegate.saveItem(
    userId: userId,
    title: title,
    subtitle: subtitle,
    type: type,
    metadata: metadata,
  );

  @override
  Future<List<SavedItem>> getUserSavedItems(int userId) =>
      _delegate.getUserSavedItems(userId);

  @override
  Future<void> deleteSavedItem(int itemId) => _delegate.deleteSavedItem(itemId);

  @override
  Future<void> close() => _delegate.close();
}

// ======================= LEGACY STUBS =======================
// These are kept for backward compatibility / tests but not used in production.

/// Web stub (legacy, unused)
class DatabaseServiceWeb implements DatabaseServiceInterface {
  @override
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Use DatabaseService() factory');
  }

  @override
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Use DatabaseService() factory');
  }

  @override
  Future<bool> userExists(String email) async => false;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User?> getUserById(int userId) async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<ChatSessionDB?> createChat({
    required int userId,
    required String title,
  }) async {
    return null;
  }

  @override
  Future<List<ChatSessionDB>> getUserChats(int userId) async => [];

  @override
  Future<void> deleteChat(int chatId) async {}

  @override
  Future<ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  }) async {
    return null;
  }

  @override
  Future<List<ChatMessageDB>> getChatMessages(int chatId) async => [];

  @override
  Future<void> clearChatMessages(int chatId) async {}

  @override
  Future<bool> updateChatTitle({
    required int chatId,
    required String title,
  }) async {
    return false;
  }

  @override
  Future<SavedItem?> saveItem({
    required int userId,
    required String title,
    required String subtitle,
    required String type,
    String? metadata,
  }) async {
    return null;
  }

  @override
  Future<List<SavedItem>> getUserSavedItems(int userId) async => [];

  @override
  Future<void> deleteSavedItem(int itemId) async {}

  @override
  Future<void> close() async {}
}

/// Native stub (legacy, unused)
class DatabaseServiceNative implements DatabaseServiceInterface {
  @override
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Use DatabaseService() factory');
  }

  @override
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    throw UnimplementedError('Use DatabaseService() factory');
  }

  @override
  Future<bool> userExists(String email) async => false;

  @override
  Future<User?> getCurrentUser() async => null;

  @override
  Future<User?> getUserById(int userId) async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<ChatSessionDB?> createChat({
    required int userId,
    required String title,
  }) async {
    return null;
  }

  @override
  Future<List<ChatSessionDB>> getUserChats(int userId) async => [];

  @override
  Future<void> deleteChat(int chatId) async {}

  @override
  Future<ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  }) async {
    return null;
  }

  @override
  Future<List<ChatMessageDB>> getChatMessages(int chatId) async => [];

  @override
  Future<void> clearChatMessages(int chatId) async {}

  @override
  Future<bool> updateChatTitle({
    required int chatId,
    required String title,
  }) async {
    return false;
  }

  @override
  Future<SavedItem?> saveItem({
    required int userId,
    required String title,
    required String subtitle,
    required String type,
    String? metadata,
  }) async {
    return null;
  }

  @override
  Future<List<SavedItem>> getUserSavedItems(int userId) async => [];

  @override
  Future<void> deleteSavedItem(int itemId) async {}

  @override
  Future<void> close() async {}
}
