import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../widgets/chat_interface.dart';

// ============================================================================
// АБСТРАКТНЫЙ ИНТЕРФЕЙС
// ============================================================================

/// Базовый интерфейс для всех реализаций хранилища чатов.
abstract class ChatStorageService {
  /// Инициализация хранилища.
  Future<void> initialize();

  /// Загрузка всех сообщений чата.
  Future<List<ChatMessage>> loadAllChats();

  /// Сохранение всех сообщений чата.
  Future<void> saveAllChats(List<ChatMessage> messages);

  /// Очистка всех сообщений чата.
  Future<void> clearChats();

  /// Проверка доступности хранилища.
  Future<bool> isAvailable();

  /// Закрытие соединения с хранилищем.
  Future<void> dispose();
}

// ============================================================================
// LOCAL STORAGE (SharedPreferences)
// ============================================================================

/// Локальное хранилище чатов через SharedPreferences.
class LocalChatStorageService implements ChatStorageService {
  static const String _kChatsKey = 'sportsense_chats';
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  @override
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  @override
  Future<List<ChatMessage>> loadAllChats() async {
    if (!_isInitialized) {
      throw StateError('LocalChatStorageService not initialized');
    }

    final jsonString = _prefs!.getString(_kChatsKey);
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

  @override
  Future<void> saveAllChats(List<ChatMessage> messages) async {
    if (!_isInitialized) {
      throw StateError('LocalChatStorageService not initialized');
    }

    final encoded = jsonEncode(messages.map((e) => e.toJson()).toList());
    await _prefs!.setString(_kChatsKey, encoded);
  }

  @override
  Future<void> clearChats() async {
    if (!_isInitialized) {
      throw StateError('LocalChatStorageService not initialized');
    }

    await _prefs!.remove(_kChatsKey);
  }

  @override
  Future<bool> isAvailable() async {
    return _isInitialized;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
    _prefs = null;
  }
}

// ============================================================================
// MONGODB STORAGE (ПОКА ОТКЛЮЧЕН)
// ============================================================================

/// Модель документа MongoDB для сообщения чата.
class MongoChatDocument {
  final String? id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final int? textColor;
  final String? sessionId;
  final String? userId;
  final Map<String, dynamic> metadata;

  MongoChatDocument({
    this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.textColor,
    this.sessionId,
    this.userId,
    this.metadata = const {},
  });

  /// Создание из ChatMessage.
  factory MongoChatDocument.fromChatMessage(
    ChatMessage message, {
    String? sessionId,
    String? userId,
  }) {
    return MongoChatDocument(
      text: message.text,
      isUser: message.isUser,
      timestamp: message.timestamp,
      textColor: message.textColor?.value,
      sessionId: sessionId,
      userId: userId,
      metadata: {},
    );
  }

  /// Преобразование в ChatMessage.
  ChatMessage toChatMessage() {
    return ChatMessage(
      text: text,
      isUser: isUser,
      timestamp: timestamp,
      textColor: textColor != null ? Color(textColor!) : null,
    );
  }

  /// Преобразование в BSON-совместимую карту.
  Map<String, dynamic> toBson() {
    return {
      if (id != null) '_id': id,
      'text': text,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      if (textColor != null) 'textColor': textColor,
      if (sessionId != null) 'sessionId': sessionId,
      if (userId != null) 'userId': userId,
      'metadata': metadata,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    };
  }

  /// Создание из BSON-карты.
  factory MongoChatDocument.fromBson(Map<String, dynamic> bson) {
    return MongoChatDocument(
      id: bson['_id']?.toString(),
      text: bson['text'] as String? ?? '',
      isUser: bson['isUser'] as bool? ?? false,
      timestamp: DateTime.tryParse(bson['timestamp'] as String? ?? '') ??
          DateTime.now(),
      textColor: bson['textColor'] as int?,
      sessionId: bson['sessionId'] as String?,
      userId: bson['userId'] as String?,
      metadata: Map<String, dynamic>.from(bson['metadata'] ?? {}),
    );
  }
}

/// Конфигурация MongoDB.
class MongoConfig {
  final String uri;
  final String databaseName;
  final String collectionName;
  final bool enabled;

  const MongoConfig({
    required this.uri,
    required this.databaseName,
    required this.collectionName,
    required this.enabled,
  });

  /// Создание конфигурации из переменных окружения.
  factory MongoConfig.fromEnv() {
    return const MongoConfig(
      uri: '', // Пустой URI означает отключенный MongoDB
      databaseName: 'sportsense',
      collectionName: 'chat_messages',
      enabled: false, // ПО УМОЛЧАНИЮ ОТКЛЮЧЕНО
    );
  }

  bool get isConfigured => uri.isNotEmpty && enabled;

  @override
  String toString() {
    return 'MongoConfig(database: $databaseName, collection: $collectionName, enabled: $enabled)';
  }
}

/// Реализация хранилища чатов на основе MongoDB.
///
/// **ВАЖНО:** Эта реализация ПОКА НАМЕРЕННО ОТКЛЮЧЕНА.
/// Для включения необходимо:
/// 1. Установить MongoDB сервер
/// 2. Настроить MONGODB_URI в .env
/// 3. Установить MONGODB_ENABLED=true в .env
class MongoChatStorageService implements ChatStorageService {
  final MongoConfig _config;
  bool _isConnected = false;

  // Заглушки для будущего использования mongo_dart
  // ignore: unused_field
  dynamic _db; // Db
  // ignore: unused_field
  dynamic _collection; // DbCollection

  MongoChatStorageService({required MongoConfig config}) : _config = config;

  @override
  Future<void> initialize() async {
    if (!_config.isConfigured) {
      print('⚠️ MongoDB отключен. URI: "${_config.uri}", Enabled: ${_config.enabled}');
      print('💡 Для включения настройте .env:');
      print('   MONGODB_URI=mongodb://localhost:27017/sportsense');
      print('   MONGODB_ENABLED=true');
      _isConnected = false;
      return;
    }

    try {
      print('🔌 Подключение к MongoDB: ${_config.uri}...');

      // TODO: Реализовать подключение с использованием mongo_dart
      // _db = await Db.create(_config.uri);
      // await _db.open();
      // _collection = _db.collection(_config.collectionName);

      // Создание индексов для оптимизации запросов
      // TODO: Реализовать создание индексов
      // await _collection.createIndex({'sessionId': 1});
      // await _collection.createIndex({'userId': 1, 'timestamp': -1});

      _isConnected = true;
      print('✅ MongoDB подключен: ${_config.databaseName}.${_config.collectionName}');
    } catch (e) {
      print('❌ Ошибка подключения к MongoDB: $e');
      _isConnected = false;
      rethrow;
    }
  }

  @override
  Future<List<ChatMessage>> loadAllChats() async {
    if (!_config.isConfigured) {
      throw StateError('MongoDB не настроен. Проверьте конфигурацию .env');
    }

    if (!_isConnected) {
      throw StateError('MongoDB не подключен. Вызовите initialize()');
    }

    try {
      // TODO: Реализовать загрузку из MongoDB
      // final messages = await _collection.find().toList();
      // return messages
      //     .map((doc) => MongoChatDocument.fromBson(doc).toChatMessage())
      //     .toList();

      print('⚠️ loadAllChats() вызван, но MongoDB еще не реализован');
      return [];
    } catch (e) {
      print('❌ Ошибка загрузки чатов из MongoDB: $e');
      return [];
    }
  }

  @override
  Future<void> saveAllChats(List<ChatMessage> messages) async {
    if (!_config.isConfigured) {
      throw StateError('MongoDB не настроен. Проверьте конфигурацию .env');
    }

    if (!_isConnected) {
      throw StateError('MongoDB не подключен. Вызовите initialize()');
    }

    try {
      // TODO: Реализовать сохранение в MongoDB
      // Вариант 1: Полная замена коллекции
      // await _collection.drop();
      // for (final message in messages) {
      //   final doc = MongoChatDocument.fromChatMessage(message).toBson();
      //   await _collection.insertOne(doc);
      // }

      // Вариант 2: Upsert по ID (рекомендуется для продакшена)
      // for (final message in messages) {
      //   final doc = MongoChatDocument.fromChatMessage(message).toBson();
      //   await _collection.updateOne(
      //     {'_id': doc['_id']},
      //     {'\$set': doc},
      //     upsert: true,
      //   );
      // }

      print('⚠️ saveAllChats() вызван, но MongoDB еще не реализован');
    } catch (e) {
      print('❌ Ошибка сохранения чатов в MongoDB: $e');
      rethrow;
    }
  }

  @override
  Future<void> clearChats() async {
    if (!_config.isConfigured) {
      throw StateError('MongoDB не настроен. Проверьте конфигурацию .env');
    }

    if (!_isConnected) {
      throw StateError('MongoDB не подключен. Вызовите initialize()');
    }

    try {
      // TODO: Реализовать очистку коллекции
      // await _collection.deleteMany({});
      print('⚠️ clearChats() вызван, но MongoDB еще не реализован');
    } catch (e) {
      print('❌ Ошибка очистки чатов в MongoDB: $e');
      rethrow;
    }
  }

  @override
  Future<bool> isAvailable() async {
    return _isConnected && _config.isConfigured;
  }

  @override
  Future<void> dispose() async {
    try {
      // TODO: Реализовать закрытие соединения
      // if (_db != null && _isConnected) {
      //   await _db.close();
      // }
      _isConnected = false;
      print('👋 MongoDB соединение закрыто');
    } catch (e) {
      print('❌ Ошибка закрытия MongoDB: $e');
    }
  }

  // ==========================================================================
  // ДОПОЛНИТЕЛЬНЫЕ МЕТОДЫ ДЛЯ БУДУЩЕГО РАСШИРЕНИЯ
  // ==========================================================================

  /// Сохранение одного сообщения (для потоковой записи).
  Future<void> saveMessage(ChatMessage message, {String? sessionId}) async {
    if (!_config.isConfigured || !_isConnected) {
      throw StateError('MongoDB не подключен');
    }

    // TODO: Реализовать сохранение одного сообщения
    // final doc = MongoChatDocument.fromChatMessage(
    //   message,
    //   sessionId: sessionId,
    // ).toBson();
    // await _collection.insertOne(doc);

    print('⚠️ saveMessage() вызван, но MongoDB еще не реализован');
  }

  /// Загрузка сообщений по sessionId.
  Future<List<ChatMessage>> loadChatsBySession(String sessionId) async {
    if (!_config.isConfigured || !_isConnected) {
      throw StateError('MongoDB не подключен');
    }

    // TODO: Реализовать загрузку по sessionId
    // final messages = await _collection
    //     .find({'sessionId': sessionId})
    //     .sort({'timestamp': 1})
    //     .toList();
    // return messages
    //     .map((doc) => MongoChatDocument.fromBson(doc).toChatMessage())
    //     .toList();

    print('⚠️ loadChatsBySession() вызван, но MongoDB еще не реализован');
    return [];
  }

  /// Удаление сообщения по ID.
  Future<bool> deleteMessage(String messageId) async {
    if (!_config.isConfigured || !_isConnected) {
      throw StateError('MongoDB не подключен');
    }

    // TODO: Реализовать удаление сообщения
    // final result = await _collection.deleteOne({'_id': messageId});
    // return result['n'] == 1;

    print('⚠️ deleteMessage() вызван, но MongoDB еще не реализован');
    return false;
  }

  /// Получение статистики коллекции.
  Future<Map<String, dynamic>?> getStats() async {
    if (!_config.isConfigured || !_isConnected) {
      return null;
    }

    // TODO: Реализовать получение статистики
    // final stats = await _collection.count();
    // return {'messageCount': stats};

    print('⚠️ getStats() вызван, но MongoDB еще не реализован');
    return null;
  }
}

// ============================================================================
// ГИБРИДНОЕ ХРАНИЛИЩЕ (MongoDB + Local fallback)
// ============================================================================

/// Гибридное хранилище с автоматическим переключением на локальное
/// при недоступности MongoDB.
class HybridChatStorageService implements ChatStorageService {
  final ChatStorageService _primary;
  final ChatStorageService _fallback;
  ChatStorageService _active;
  bool _useFallback = false;

  HybridChatStorageService({
    required ChatStorageService primary,
    required ChatStorageService fallback,
  })  : _primary = primary,
        _fallback = fallback,
        _active = fallback;

  @override
  Future<void> initialize() async {
    await _fallback.initialize();

    try {
      await _primary.initialize();
      if (await _primary.isAvailable()) {
        _active = _primary;
        _useFallback = false;
        print('✅ HybridChatStorage: активен PRIMARY (${_primary.runtimeType})');
      } else {
        _active = _fallback;
        _useFallback = true;
        print('⚠️ HybridChatStorage: PRIMARY недоступен, активен FALLBACK (${_fallback.runtimeType})');
      }
    } catch (e) {
      _active = _fallback;
      _useFallback = true;
      print('⚠️ HybridChatStorage: ошибка PRIMARY ($e), активен FALLBACK');
    }
  }

  @override
  Future<List<ChatMessage>> loadAllChats() async {
    return _active.loadAllChats();
  }

  @override
  Future<void> saveAllChats(List<ChatMessage> messages) async {
    await _active.saveAllChats(messages);

    // Асинхронная синхронизация с fallback для надежности
    if (!_useFallback) {
      try {
        await _fallback.saveAllChats(messages);
      } catch (e) {
        print('⚠️ Не удалось синхронизировать с fallback: $e');
      }
    }
  }

  @override
  Future<void> clearChats() async {
    await _active.clearChats();
    if (!_useFallback) {
      await _fallback.clearChats();
    }
  }

  @override
  Future<bool> isAvailable() async {
    return _active.isAvailable();
  }

  @override
  Future<void> dispose() async {
    await _primary.dispose();
    await _fallback.dispose();
  }

  /// Текущий активный сервис.
  ChatStorageService get activeService => _active;

  /// Используется ли fallback.
  bool get isUsingFallback => _useFallback;
}
