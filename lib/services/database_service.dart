import 'package:flutter/foundation.dart' show kIsWeb;

// Импортируем модели и интерфейс
import 'database_models.dart';

// Импортируем веб-реализацию
import 'database_service_web.dart';

/// Инициализация базы данных для разных платформ
void initDatabase() {
  if (!kIsWeb) {
    // Инициализация FFI для Desktop (Windows, Linux, macOS)
    _initNativeDatabase();
  }
  // Для веба используется in-memory реализация
}

/// Инициализация нативной базы данных (только для мобильных/десктоп)
void _initNativeDatabase() {
  try {
    // На данный момент используем in-memory реализацию для всех платформ
    // В будущем здесь можно добавить инициализацию SQLite для нативных платформ
    print('Инициализация нативной базы данных');
  } catch (e) {
    print('Предупреждение: Не удалось инициализировать базу данных: $e');
  }
}

/// Сервис для работы с базой данных (платформо-зависимый)
/// Это обёртка, которая делегирует вызовы к конкретной реализации
class DatabaseService implements DatabaseServiceInterface {
  static DatabaseServiceInterface? _instance;
  
  /// Получить экземпляр сервиса (фабричный метод)
  factory DatabaseService() {
    if (_instance == null) {
      if (kIsWeb) {
        _instance = DatabaseServiceWeb();
      } else {
        _instance = DatabaseServiceNative();
      }
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
  Future<User?> loginUser({
    required String email,
    required String password,
  }) => _delegate.loginUser(email: email, password: password);

  @override
  Future<bool> userExists(String email) => _delegate.userExists(email);

  @override
  Future<User?> getCurrentUser() => _delegate.getCurrentUser();

  @override
  Future<void> logout() => _delegate.logout();

  @override
  Future<ChatSessionDB?> createChat({
    required int userId,
    required String title,
  }) => _delegate.createChat(userId: userId, title: title);

  @override
  Future<List<ChatSessionDB>> getUserChats(int userId) => _delegate.getUserChats(userId);

  @override
  Future<void> deleteChat(int chatId) => _delegate.deleteChat(chatId);

  @override
  Future<ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  }) => _delegate.addMessage(chatId: chatId, text: text, isUser: isUser);

  @override
  Future<List<ChatMessageDB>> getChatMessages(int chatId) => _delegate.getChatMessages(chatId);

  @override
  Future<void> clearChatMessages(int chatId) => _delegate.clearChatMessages(chatId);

  @override
  Future<bool> updateChatTitle({
    required int chatId,
    required String title,
  }) => _delegate.updateChatTitle(chatId: chatId, title: title);

  @override
  Future<void> close() => _delegate.close();
}

/// Нативная реализация базы данных (для мобильных/десктоп)
/// На данный момент использует in-memory хранилище
class DatabaseServiceNative implements DatabaseServiceInterface {
  // Хранилище данных в памяти
  final Map<int, User> _users = {};
  final Map<int, ChatSessionDB> _chats = {};
  final Map<int, ChatMessageDB> _messages = {};
  
  int _nextUserId = 1;
  int _nextChatId = 1;
  int _nextMessageId = 1;

  DatabaseServiceNative() {
    print('Используется in-memory база данных для нативной платформы');
  }

  @override
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      // Проверяем, существует ли пользователь с таким email
      final existingUser = _users.values.where((u) => u.email == email).firstOrNull;
      if (existingUser != null) {
        print('Пользователь с таким email уже существует');
        return null;
      }

      final passwordHash = hashPassword(password);
      final user = User(
        id: _nextUserId++,
        name: name,
        email: email,
        passwordHash: passwordHash,
        createdAt: DateTime.now(),
      );

      _users[user.id!] = user;
      print('Пользователь зарегистрирован: ${user.email}');
      return user;
    } catch (e) {
      print('Ошибка регистрации: $e');
      return null;
    }
  }

  @override
  Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      final passwordHash = hashPassword(password);
      final user = _users.values.where(
        (u) => u.email == email && u.passwordHash == passwordHash,
      ).firstOrNull;

      if (user != null) {
        print('Пользователь вошел: ${user.email}');
      } else {
        print('Неверный email или пароль');
      }
      return user;
    } catch (e) {
      print('Ошибка входа: $e');
      return null;
    }
  }

  @override
  Future<bool> userExists(String email) async {
    try {
      return _users.values.any((u) => u.email == email);
    } catch (e) {
      print('Ошибка проверки пользователя: $e');
      return false;
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      if (_users.isEmpty) return null;
      return _users.values.last;
    } catch (e) {
      print('Ошибка получения пользователя: $e');
      return null;
    }
  }

  @override
  Future<void> logout() async {
    // В обеих реализациях ничего не делаем
  }

  @override
  Future<ChatSessionDB?> createChat({
    required int userId,
    required String title,
  }) async {
    try {
      final chat = ChatSessionDB(
        id: _nextChatId++,
        userId: userId,
        title: title,
        createdAt: DateTime.now(),
      );

      _chats[chat.id!] = chat;
      print('Чат создан: ${chat.title}');
      return chat;
    } catch (e) {
      print('Ошибка создания чата: $e');
      return null;
    }
  }

  @override
  Future<List<ChatSessionDB>> getUserChats(int userId) async {
    try {
      return _chats.values
          .where((chat) => chat.userId == userId)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      print('Ошибка получения чатов: $e');
      return [];
    }
  }

  @override
  Future<void> deleteChat(int chatId) async {
    try {
      _chats.remove(chatId);
      _messages.removeWhere((_, msg) => msg.chatId == chatId);
      print('Чат удален: $chatId');
    } catch (e) {
      print('Ошибка удаления чата: $e');
    }
  }

  @override
  Future<ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  }) async {
    try {
      final message = ChatMessageDB(
        id: _nextMessageId++,
        chatId: chatId,
        text: text,
        isUser: isUser,
        timestamp: DateTime.now(),
      );

      _messages[message.id!] = message;
      return message;
    } catch (e) {
      print('Ошибка добавления сообщения: $e');
      return null;
    }
  }

  @override
  Future<List<ChatMessageDB>> getChatMessages(int chatId) async {
    try {
      return _messages.values
          .where((msg) => msg.chatId == chatId)
          .toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    } catch (e) {
      print('Ошибка получения сообщений: $e');
      return [];
    }
  }

  @override
  Future<void> clearChatMessages(int chatId) async {
    try {
      _messages.removeWhere((_, msg) => msg.chatId == chatId);
      print('Сообщения чата очищены: $chatId');
    } catch (e) {
      print('Ошибка очистки сообщений: $e');
    }
  }

  @override
  Future<bool> updateChatTitle({
    required int chatId,
    required String title,
  }) async {
    try {
      final chat = _chats[chatId];
      if (chat == null) {
        print('Чат не найден: $chatId');
        return false;
      }
      
      final updatedChat = chat.copyWith(title: title);
      _chats[chatId] = updatedChat;
      print('Название чата обновлено: $chatId -> $title');
      return true;
    } catch (e) {
      print('Ошибка обновления названия чата: $e');
      return false;
    }
  }

  @override
  Future<void> close() async {
    // В обеих реализациях ничего не делаем
  }

  /// Очистить все данные
  void clear() {
    _users.clear();
    _chats.clear();
    _messages.clear();
    _nextUserId = 1;
    _nextChatId = 1;
    _nextMessageId = 1;
  }
}