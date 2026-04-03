import 'local_vector_db.dart';
import 'user_query_vectorizer.dart';

/// Менеджер персональных векторных баз для каждого чата.
/// 
/// Каждый чат имеет свою собственную векторную базу для хранения
/// эмбеддингов сообщений и их суммаризации.
class ChatVectorDbManager {
  final LocalVectorDatabase _globalDb;
  final UserQueryVectorizerService _vectorizer;
  
  // Маппинг chatId -> collectionName
  final Map<String, String> _chatCollections = {};
  
  // Размерность векторов (зависит от модели эмбеддингов)
  static const int vectorSize = 768;
  
  ChatVectorDbManager({
    required LocalVectorDatabase globalDb,
    required UserQueryVectorizerService vectorizer,
  })  : _globalDb = globalDb,
        _vectorizer = vectorizer;

  /// Инициализация векторной базы для конкретного чата.
  /// 
  /// [chatId] - уникальный идентификатор чата
  /// Создает новую коллекцию в векторной базе для этого чата.
  Future<bool> initializeChatVectorDb(String chatId) async {
    try {
      final collectionName = 'chat_$chatId';
      
      // Проверяем, существует ли уже коллекция
      if (_chatCollections.containsKey(chatId)) {
        print('✓ Векторная база для чата $chatId уже существует');
        return true;
      }
      
      // Создаем коллекцию
      _globalDb.createCollection(
        name: collectionName,
        vectorSize: vectorSize,
        distanceMetric: 'Cosine',
      );
      
      _chatCollections[chatId] = collectionName;
      print('✓ Создана векторная база для чата: $collectionName');
      return true;
    } catch (e) {
      print('❌ Ошибка создания векторной базы для чата $chatId: $e');
      return false;
    }
  }

  /// Добавляет сообщение чата в векторную базу.
  /// 
  /// [chatId] - ID чата
  /// [messageId] - ID сообщения
  /// [text] - текст сообщения
  /// [isUser] - true если сообщение от пользователя
  /// [metadata] - дополнительные метаданные
  Future<bool> addMessage({
    required String chatId,
    required int messageId,
    required String text,
    required bool isUser,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final collectionName = _chatCollections[chatId];
      if (collectionName == null) {
        print('⚠️ Векторная база для чата $chatId не инициализирована');
        await initializeChatVectorDb(chatId);
      }
      
      // Векторизуем текст сообщения
      final vectorResult = await _vectorizer.vectorizeQuery(text);
      
      // Подготавливаем payload
      final payload = {
        'chat_id': chatId,
        'message_id': messageId,
        'text': text,
        'is_user': isUser,
        'timestamp': DateTime.now().toIso8601String(),
        ...?metadata,
      };
      
      // Добавляем в векторную базу
      final success = _globalDb.upsert(
        collectionName: 'chat_$chatId',
        id: messageId,
        vector: vectorResult.vector,
        payload: payload,
      );
      
      if (success) {
        print('✓ Добавлено сообщение $messageId в векторную базу чата $chatId');
      }
      
      return success;
    } catch (e) {
      print('❌ Ошибка добавления сообщения в векторную базу: $e');
      return false;
    }
  }

  /// Поиск релевантных сообщений в истории чата.
  /// 
  /// [chatId] - ID чата
  /// [query] - поисковый запрос
  /// [limit] - максимальное количество результатов
  /// Возвращает список релевантных сообщений с оценкой схожести.
  Future<List<Map<String, dynamic>>?> searchRelevantMessages({
    required String chatId,
    required String query,
    int limit = 5,
  }) async {
    try {
      final collectionName = _chatCollections[chatId];
      if (collectionName == null) {
        print('⚠️ Векторная база для чата $chatId не найдена');
        return null;
      }
      
      // Векторизуем запрос
      final queryVectorResult = await _vectorizer.vectorizeQuery(query);
      
      // Ищем релевантные сообщения
      final results = _globalDb.search(
        collectionName: collectionName,
        vector: queryVectorResult.vector,
        limit: limit,
      );
      
      if (results != null && results.isNotEmpty) {
        print('✓ Найдено ${results.length} релевантных сообщений для чата $chatId');
        return results;
      }
      
      return [];
    } catch (e) {
      print('❌ Ошибка поиска в векторной базе чата: $e');
      return null;
    }
  }

  /// Генерирует контекст для RAG из истории чата.
  /// 
  /// [chatId] - ID чата
  /// [query] - текущий запрос пользователя
  /// [limit] - количество сообщений для контекста
  /// Возвращает форматированную строку контекста.
  Future<String> generateRagContext({
    required String chatId,
    required String query,
    int limit = 5,
  }) async {
    final results = await searchRelevantMessages(
      chatId: chatId,
      query: query,
      limit: limit,
    );
    
    if (results == null || results.isEmpty) {
      return '';
    }
    
    final buffer = StringBuffer();
    buffer.writeln('Контекст из истории чата:');
    buffer.writeln('');
    
    for (final result in results) {
      final payload = result['payload'] as Map<String, dynamic>?;
      if (payload != null) {
        final isUser = payload['is_user'] == true || payload['is_user'] == 1;
        final text = payload['text']?.toString() ?? '';
        final score = result['score']?.toStringAsFixed(2) ?? '0';
        
        if (text.isNotEmpty) {
          buffer.writeln('[Схожесть: $score] ${isUser ? "Пользователь" : "Бот"}: $text');
        }
      }
    }
    
    return buffer.toString();
  }

  /// Получает статистику векторной базы чата.
  /// 
  /// [chatId] - ID чата
  /// Возвращает статистику коллекции.
  Map<String, dynamic>? getChatStats(String chatId) {
    final collectionName = _chatCollections[chatId];
    if (collectionName == null) return null;
    
    final stats = _globalDb.stats;
    final collectionDetails = stats['collectionDetails'] as Map<String, dynamic>?;
    
    if (collectionDetails != null && collectionDetails.containsKey(collectionName)) {
      return {
        'chat_id': chatId,
        'collection_name': collectionName,
        'message_count': collectionDetails[collectionName],
      };
    }
    
    return null;
  }

  /// Удаляет векторную базу чата.
  /// 
  /// [chatId] - ID чата
  Future<bool> deleteChatVectorDb(String chatId) async {
    try {
      final collectionName = _chatCollections[chatId];
      if (collectionName == null) {
        print('⚠️ Векторная база для чата $chatId не найдена');
        return false;
      }
      
      _globalDb.deleteCollection(collectionName);
      _chatCollections.remove(chatId);
      
      print('✓ Удалена векторная база для чата: $collectionName');
      return true;
    } catch (e) {
      print('❌ Ошибка удаления векторной базы чата: $e');
      return false;
    }
  }

  /// Очищает векторную базу чата (удаляет все сообщения).
  /// 
  /// [chatId] - ID чата
  Future<bool> clearChatVectorDb(String chatId) async {
    try {
      // Удаляем и пересоздаем коллекцию
      await deleteChatVectorDb(chatId);
      await initializeChatVectorDb(chatId);
      
      print('✓ Очищена векторная база для чата: $chatId');
      return true;
    } catch (e) {
      print('❌ Ошибка очистки векторной базы чата: $e');
      return false;
    }
  }

  /// Проверяет, инициализирована ли векторная база для чата.
  bool isChatVectorDbInitialized(String chatId) {
    return _chatCollections.containsKey(chatId);
  }

  /// Получает список всех чатов с векторными базами.
  List<String> get initializedChats => _chatCollections.keys.toList();

  /// Общая статистика всех векторных баз чатов.
  Map<String, dynamic> get overallStats {
    return {
      'total_chats': _chatCollections.length,
      'chat_ids': _chatCollections.keys.toList(),
      'global_db_stats': _globalDb.stats,
    };
  }
}