import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qdrant_client.dart';
import 'trigger_constants.dart';
import 'local_embedding.dart';

/// Сервис для работы с триггерными словами в векторной базе Qdrant.
/// Использует локальный TF-IDF эмбеддинг для семантического поиска.
/// Триггерные слова хранятся как константы в единой неизменной базе.
class TriggerWordsService {
  final QdrantClient _qdrant;
  final LocalEmbedding _embedding;
  
  /// Название коллекции (единая база для всех триггеров)
  final String _collectionName = UefaTriggerConstants.collectionName;
  
  /// Порог схожести
  final double _threshold = UefaTriggerConstants.similarityThreshold;
  
  /// Кэш векторов триггеров
  final Map<int, List<double>> _vectorCache = {};
  
  /// Инициализирован ли сервис
  bool _isInitialized = false;

  TriggerWordsService({
    QdrantClient? qdrant,
    LocalEmbedding? embedding,
  })  : _qdrant = qdrant ?? QdrantClient(
          url: dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333',
          apiKey: dotenv.env['QDRANT_API_KEY'],
        ),
        _embedding = embedding ?? LocalEmbedding();

  /// Инициализация единой базы триггеров
  /// Обучает локальный эмбеддинг и загружает константные триггеры
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    // Обучение локального эмбеддинга на константных триггерах
    final triggers = UefaTriggerConstants.all;
    _embedding.train(triggers);
    
    debugPrint('LocalEmbedding обучен на ${triggers.length} триггерах, словарь: ${_embedding.vocabularySize} слов');
    
    // Проверка существования коллекции в Qdrant
    final exists = await _qdrant.collectionExists(_collectionName);
    
    if (!exists) {
      final created = await _qdrant.createCollection(
        collectionName: _collectionName,
        vectorSize: _embedding.vocabularySize,
        distance: 'Cosine',
      );
      if (!created) return false;
      
      // Загрузка константных триггеров в базу
      await _loadConstantTriggers();
    }
    
    _isInitialized = true;
    return true;
  }

  /// Загрузка константных триггеров в базу (вызывается один раз при создании)
  Future<void> _loadConstantTriggers() async {
    final triggers = UefaTriggerConstants.all;
    final points = <Map<String, dynamic>>[];

    for (var i = 0; i < triggers.length; i++) {
      final trigger = triggers[i];
      final vector = _embedding.transform(trigger);
      _vectorCache[i] = vector; // Кэшируем вектор
      
      points.add({
        'id': i,
        'vector': vector,
        'payload': {
          'text': trigger,
          'language': _getLanguage(trigger),
          'is_constant': true, // Метка что это константное значение
        },
      });
    }

    if (points.isNotEmpty) {
      await _qdrant.upsertPoints(
        collectionName: _collectionName,
        points: points,
      );
      debugPrint('Загружено ${points.length} триггеров в Qdrant');
    }
  }

  /// Определение языка фразы
  String _getLanguage(String text) {
    final russianPattern = RegExp(r'[а-яА-ЯёЁ]');
    return russianPattern.hasMatch(text) ? 'ru' : 'en';
  }

  /// Поиск триггера в запросе пользователя с помощью локального эмбеддинга
  /// Возвращает найденные триггеры с оценкой схожести
  Future<List<Map<String, dynamic>>> findTriggers(String query, {
    double? threshold,
    bool useLocalOnly = false,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final effectiveThreshold = threshold ?? _threshold;
    
    // Используем локальный TF-IDF для быстрого поиска
    final localResults = _embedding.searchSimilar(query, limit: 5);
    
    debugPrint('LocalEmbedding нашёл ${localResults.length} похожих для "$query"');
    for (var result in localResults) {
      debugPrint('  - "${result['text']}": ${result['score'].toStringAsFixed(3)}');
    }
    
    // Фильтрация по порогу
    final filtered = localResults
        .where((result) => (result['score'] as num).toDouble() >= effectiveThreshold)
        .toList();
    
    return filtered.map((result) => {
      'id': result['index'],
      'score': result['score'],
      'payload': {
        'text': result['text'],
        'language': _getLanguage(result['text']),
      },
    }).toList();
  }

  /// Проверка наличия триггера в запросе
  /// Возвращает true если найден хотя бы один триггер
  Future<bool> hasTrigger(String query, {double? threshold}) async {
    final matches = await findTriggers(query, threshold: threshold);
    return matches.isNotEmpty;
  }

  /// Получение всех константных триггеров
  List<String> getAllTriggers() {
    return UefaTriggerConstants.all;
  }
  
  /// Тестирование эмбеддинга на похожих запросах
  void debugTestEmbedding() {
    final testQueries = [
      'ranking',
      'рейтинг',
      'uefa rankings',
      'рейтинг клубов',
      'table',
      'таблица',
    ];
    
    debugPrint('\n=== Тест LocalEmbedding ===');
    for (var query in testQueries) {
      final results = _embedding.searchSimilar(query, limit: 3);
      debugPrint('Запрос: "$query"');
      for (var r in results) {
        debugPrint('  ${r['score'].toStringAsFixed(3)} - ${r['text']}');
      }
    }
    debugPrint('========================\n');
  }
}
