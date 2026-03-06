import 'package:flutter/foundation.dart';
import 'trigger_constants.dart';
import 'trigger_words_loader.dart';

/// Сервис для работы с триггерными словами в векторной базе Qdrant.
/// Использует локальную векторизацию и Qdrant для хранения.
/// Триггерные слова загружаются из assets/trigger_words.txt
class TriggerWordsService {
  final TriggerWordsLoader _loader;
  
  /// Порог схожести
  final double _threshold = UefaTriggerConstants.similarityThreshold;
  
  /// Инициализирован ли сервис
  bool _isInitialized = false;

  TriggerWordsService({
    TriggerWordsLoader? loader,
  }) : _loader = loader ?? TriggerWordsLoader();

  /// Инициализация сервиса
  /// Загружает триггеры из txt файла в Qdrant
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      final success = await _loader.initialize();
      _isInitialized = success;
      
      if (success) {
        final count = await _loader.getTriggerCount();
        debugPrint('✅ TriggerWordsService инициализирован: $count триггеров в Qdrant');
      } else {
        debugPrint('⚠️ Ошибка инициализации TriggerWordsService');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ Ошибка инициализации: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Поиск триггеров в запросе
  Future<List<Map<String, dynamic>>> findTriggers(String query, {
    double? threshold,
    int limit = 5,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final effectiveThreshold = threshold ?? _threshold;
    
    try {
      final results = await _loader.searchSimilar(
        query,
        limit: limit,
        threshold: effectiveThreshold,
      );
      
      if (kDebugMode) {
        debugPrint('🔍 Найдено ${results.length} триггеров для "$query"');
        for (var r in results) {
          final text = r['payload']?['text'] ?? 'unknown';
          final score = (r['score'] as num?)?.toDouble() ?? 0;
          debugPrint('  - $text: ${score.toStringAsFixed(3)}');
        }
      }
      
      return results;
    } catch (e) {
      debugPrint('Ошибка поиска триггеров: $e');
      return [];
    }
  }

  /// Проверка наличия триггера в запросе
  Future<bool> hasTrigger(String query, {double? threshold}) async {
    final matches = await findTriggers(query, threshold: threshold);
    return matches.isNotEmpty;
  }
  
  /// Получить количество триггеров
  Future<int> getTriggerCount() async {
    return await _loader.getTriggerCount();
  }
  
  /// Перезагрузка триггеров
  Future<bool> reload() async {
    return await _loader.reload();
  }
  
  /// Тестирование на примерах
  void debugTestEmbedding() {
    final testQueries = [
      'ranking',
      'рейтинг',
      'uefa rankings',
      'рейтинг клубов',
      'table',
      'таблица',
      'BANANA-HEY',
    ];
    
    debugPrint('\n=== Тест TriggerWordsService ===');
    for (var query in testQueries) {
      _loader.searchSimilar(query, limit: 3).then((results) {
        debugPrint('Запрос: "$query"');
        for (var r in results) {
          final text = r['payload']?['text'] ?? 'unknown';
          final score = (r['score'] as num?)?.toDouble() ?? 0;
          debugPrint('  ${score.toStringAsFixed(3)} - $text');
        }
      });
    }
    debugPrint('================================\n');
  }
}
