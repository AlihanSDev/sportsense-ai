import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qdrant_client.dart';

/// Сервис для работы с триггерными словами в векторной базе Qdrant.
/// Векторизует фразы и выполняет семантический поиск.
class TriggerWordsService {
  final QdrantClient _qdrant;
  final String _collectionName = 'uefa_triggers';
  
  // Простая хэш-функция для демонстрации (в будущем заменить на эмбеддинги)
  List<double> _vectorize(String text) {
    const vectorSize = 384;
    final vector = List<double>.filled(vectorSize, 0.0);
    final normalizedText = text.toLowerCase().trim();
    
    // Простая векторизация на основе хэша символов
    for (var i = 0; i < normalizedText.length; i++) {
      final charCode = normalizedText.codeUnitAt(i);
      final index = (charCode + i) % vectorSize;
      vector[index] += (charCode % 100) / 100.0;
    }
    
    // Нормализация вектора
    final magnitude = sqrt(vector.fold<double>(
      0.0,
      (sum, val) => sum + val * val,
    ));
    
    if (magnitude > 0) {
      for (var i = 0; i < vector.length; i++) {
        vector[i] /= magnitude;
      }
    }
    
    return vector;
  }

  TriggerWordsService({QdrantClient? qdrant})
      : _qdrant = qdrant ??
            QdrantClient(
              url: dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333',
              apiKey: dotenv.env['QDRANT_API_KEY'],
            );

  /// Инициализация коллекции с триггерными словами
  Future<bool> initialize() async {
    // Проверка существования коллекции
    final exists = await _qdrant.collectionExists(_collectionName);
    
    if (!exists) {
      final created = await _qdrant.createCollection(
        collectionName: _collectionName,
        vectorSize: 384,
        distance: 'Cosine',
      );
      if (!created) return false;
    }

    // Загрузка триггерных слов
    await _loadTriggerWords();
    return true;
  }

  /// Загрузка триггерных слов в базу
  Future<void> _loadTriggerWords() async {
    final triggers = _getTriggerWords();
    final points = <Map<String, dynamic>>[];

    for (var i = 0; i < triggers.length; i++) {
      final trigger = triggers[i];
      final vector = _vectorize(trigger);
      
      points.add({
        'id': i,
        'vector': vector,
        'payload': {
          'text': trigger,
          'language': _getLanguage(trigger),
        },
      });
    }

    if (points.isNotEmpty) {
      await _qdrant.upsertPoints(
        collectionName: _collectionName,
        points: points,
      );
    }
  }

  /// Получение списка триггерных слов
  List<String> _getTriggerWords() {
    return [
      // English
      'ranking',
      'rankings',
      'uefa ranking',
      'uefa rankings',
      'club ranking',
      'club rankings',
      'team ranking',
      'team rankings',
      'uefa table',
      'uefa standings',
      'coefficient ranking',
      'uefa coefficient',
      // Russian
      'рейтинг',
      'рейтинги',
      'рейтинг клубов',
      'рейтинг uefa',
      'таблица uefa',
      'коэффициент uefa',
      'еврокубковый рейтинг',
      'позиция в рейтинге',
    ];
  }

  /// Определение языка фразы
  String _getLanguage(String text) {
    final russianPattern = RegExp(r'[а-яА-ЯёЁ]');
    return russianPattern.hasMatch(text) ? 'ru' : 'en';
  }

  /// Поиск триггера в запросе пользователя
  Future<List<Map<String, dynamic>>> findTriggers(String query,
      {double threshold = 0.7}) async {
    final queryVector = _vectorize(query);
    
    final results = await _qdrant.searchPoints(
      collectionName: _collectionName,
      vector: queryVector,
      limit: 5,
    );

    // Фильтрация по порогу схожести
    return results
        .where((result) => (result['score'] as num?)?.toDouble() ?? 0 >= threshold)
        .toList();
  }

  /// Проверка наличия триггера в запросе
  Future<bool> hasTrigger(String query, {double threshold = 0.7}) async {
    final matches = await findTriggers(query, threshold: threshold);
    return matches.isNotEmpty;
  }

  /// Очистка базы триггеров
  Future<bool> clear() async {
    return await _qdrant.clearCollection(_collectionName);
  }

  /// Перезагрузка триггерных слов
  Future<bool> reload() async {
    await clear();
    await _loadTriggerWords();
    return true;
  }
}
