import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Модель пользователя
class User {
  final int? id;
  final String name;
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  User({
    this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'password_hash': passwordHash,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      name: map['name'],
      email: map['email'],
      passwordHash: map['password_hash'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  User copyWith({
    int? id,
    String? name,
    String? email,
    String? passwordHash,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Модель сообщения чата
class ChatMessageDB {
  final int? id;
  final int chatId;
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessageDB({
    this.id,
    required this.chatId,
    required this.text,
    required this.isUser,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'text': text,
      'is_user': isUser ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory ChatMessageDB.fromMap(Map<String, dynamic> map) {
    return ChatMessageDB(
      id: map['id'],
      chatId: map['chat_id'],
      text: map['text'],
      isUser: map['is_user'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
    );
  }

  ChatMessageDB copyWith({
    int? id,
    int? chatId,
    String? text,
    bool? isUser,
    DateTime? timestamp,
  }) {
    return ChatMessageDB(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

/// Модель чата
class ChatSessionDB {
  final int? id;
  final int userId;
  final String title;
  final DateTime createdAt;

  ChatSessionDB({
    this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory ChatSessionDB.fromMap(Map<String, dynamic> map) {
    return ChatSessionDB(
      id: map['id'],
      userId: map['user_id'],
      title: map['title'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  ChatSessionDB copyWith({
    int? id,
    int? userId,
    String? title,
    DateTime? createdAt,
  }) {
    return ChatSessionDB(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

/// Абстрактный интерфейс для сервиса базы данных
abstract class DatabaseServiceInterface {
  Future<User?> registerUser({
    required String name,
    required String email,
    required String password,
  });
  
  Future<User?> loginUser({
    required String email,
    required String password,
  });
  
  Future<bool> userExists(String email);
  
  Future<User?> getCurrentUser();
  
  Future<void> logout();
  
  Future<ChatSessionDB?> createChat({
    required int userId,
    required String title,
  });
  
  Future<List<ChatSessionDB>> getUserChats(int userId);
  
  Future<void> deleteChat(int chatId);
  
  Future<ChatMessageDB?> addMessage({
    required int chatId,
    required String text,
    required bool isUser,
  });
  
  Future<List<ChatMessageDB>> getChatMessages(int chatId);
  
  Future<void> clearChatMessages(int chatId);
  
  Future<void> close();
}

/// Утилиты для работы с паролями
String hashPassword(String password) {
  final bytes = utf8.encode(password);
  final hash = sha256.convert(bytes);
  return hash.toString();
}