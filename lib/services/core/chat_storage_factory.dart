import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'chat_storage_service.dart';

/// Фабрика для создания сервиса хранения чатов.
///
/// Автоматически выбирает между MongoDB и локальным хранилищем
/// на основе конфигурации в .env.
class ChatStorageFactory {
  /// Создание сервиса хранения чатов на основе конфигурации.
  ///
  /// Если MongoDB включен и настроен - возвращается [MongoChatStorageService].
  /// Иначе - возвращается [LocalChatStorageService].
  static Future<ChatStorageService> create() async {
    final config = MongoConfig.fromEnv();

    print('📦 ChatStorageFactory: создание сервиса...');
    print('   MongoDB URI: "${config.uri.isEmpty ? '(пусто)' : '(настроен)'}"');
    print('   MongoDB Enabled: ${config.enabled}');
    print('   MongoDB IsConfigured: ${config.isConfigured}');

    if (config.isConfigured) {
      print('🟢 Выбор: MongoDB хранилище');
      return MongoChatStorageService(config: config);
    } else {
      print('🟡 Выбор: Локальное хранилище (SharedPreferences)');
      return LocalChatStorageService();
    }
  }

  /// Создание гибридного сервиса с MongoDB как основным и локальным как резервным.
  ///
  /// Если MongoDB недоступен, автоматически переключается на локальное хранилище.
  static Future<HybridChatStorageService> createHybrid() async {
    final config = MongoConfig.fromEnv();
    final mongoService = MongoChatStorageService(config: config);
    final localService = LocalChatStorageService();

    print('📦 ChatStorageFactory: создание ГИБРИДНОГО сервиса...');

    return HybridChatStorageService(
      primary: mongoService,
      fallback: localService,
    );
  }

  /// Проверка, включен ли MongoDB в конфигурации.
  static bool isMongoEnabled() {
    try {
      final enabled = dotenv.env['MONGODB_ENABLED'] ?? 'false';
      final uri = dotenv.env['MONGODB_URI'] ?? '';
      return enabled.toLowerCase() == 'true' && uri.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Получение текущей конфигурации MongoDB.
  static MongoConfig getCurrentConfig() {
    return MongoConfig.fromEnv();
  }
}
