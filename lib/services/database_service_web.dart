import 'database_models.dart';

/// Веб-совместимый сервис базы данных (хранение в памяти)
class DatabaseServiceWeb implements DatabaseServiceInterface {
  static final DatabaseServiceWeb _instance = DatabaseServiceWeb._internal();
  
  // Хранилище данных в памяти
  final Map<int, User> _users = {};
  final Map<int, ChatSessionDB> _chats = {};
  final Map<int, ChatMessageDB> _messages = {};
  
  int _nextUserId = 1;
  int _nextChatId = 1;
  int _nextMessageId = 1;

  DatabaseServiceWeb._internal();

  factory DatabaseServiceWeb() {
    return _instance;
  }

  // ======================= ПОЛЬЗОВАТЕЛИ =======================

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
    // В веб-реализации ничего не делаем
  }

  // ======================= ЧАТЫ =======================

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
      // Удаляем все сообщения чата
      _messages.removeWhere((_, msg) => msg.chatId == chatId);
      print('Чат удален: $chatId');
    } catch (e) {
      print('Ошибка удаления чата: $e');
    }
  }

  // ======================= СООБЩЕНИЯ =======================

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
  Future<void> close() async {
    // В веб-реализации ничего не делаем
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