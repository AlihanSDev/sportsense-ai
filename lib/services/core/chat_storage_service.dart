import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/chat_interface.dart';

/// Локальное хранилище чатов через SharedPreferences.
class LocalChatStorageService {
  static const String _kChatsKey = 'sportsense_chats';

  Future<void> initialize() async {
    // Здесь можно расширить и подготовить локальную БД.
    await SharedPreferences.getInstance();
  }

  Future<List<ChatMessage>> loadAllChats() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_kChatsKey);
    if (jsonString == null || jsonString.isEmpty) return [];

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) return [];
      return decoded
          .map((e) => ChatMessage.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAllChats(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(messages.map((e) => e.toJson()).toList());
    await prefs.setString(_kChatsKey, encoded);
  }

  Future<void> clearChats() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kChatsKey);
  }
}

/// Заготовка для MongoDB. Пока не подключен Mongo, меседж сохраняется локально.
class MongoChatStorageService {
  bool _isConnected = false;

  Future<void> connect() async {
    // TODO: Реализовать подключение к MongoDB.
    _isConnected = false;
    throw UnimplementedError('MongoDB backend is not configured yet.');
  }

  Future<void> saveAllChats(List<ChatMessage> messages) async {
    if (!_isConnected) {
      throw StateError('MongoDB not connected.');
    }
    // Здесь будет логика записи в Mongo
  }

  Future<List<ChatMessage>> loadAllChats() async {
    if (!_isConnected) {
      throw StateError('MongoDB not connected.');
    }
    // Здесь будет логика чтения из Mongo
    return [];
  }

  Future<void> disconnect() async {
    _isConnected = false;
  }
}
