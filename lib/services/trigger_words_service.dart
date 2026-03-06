import 'dart:math';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'qdrant_client.dart';
import 'trigger_constants.dart';

/// Сервис для работы с триггерными словами в векторной базе Qdrant.
/// Триггерные слова хранятся как константы в единой неизменной базе.
class TriggerWordsService {
  final QdrantClient _qdrant;
  
  /// Название коллекции (единая база для всех триггеров)
  final String _collectionName = UefaTriggerConstants.collectionName;
  
  /// Порог схожести
  final double _threshold = UefaTriggerConstants.similarityThreshold;

  /// Кэш векторов триггеров (чтобы не пересчитывать)
  final Map<int, List<double>> _vectorCache = {};

  TriggerWordsService({QdrantClient? qdrant})
      : _qdrant = qdrant ??
            QdrantClient(
              url: dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333',
              apiKey: dotenv.env['QDRANT_API_KEY'],
            );

  /// Инициализация единой базы триггеров
  /// Создаёт коллекцию и загружает константные триггеры (только один раз)
  Future<bool> initialize() async {
    // Проверка существования коллекции
    final exists = await _qdrant.collectionExists(_collectionName);
    
    if (!exists) {
      final created = await _qdrant.createCollection(
        collectionName: _collectionName,
        vectorSize: UefaTriggerConstants.vectorSize,
        distance: 'Cosine',
      );
      if (!created) return false;
      
      // Загрузка константных триггеров в базу
      await _loadConstantTriggers();
    }
    
    return true;
  }

  /// Векторизация текста (простая хэш-функция для демонстрации)
  /// В будущем заменить на настоящую модель эмбеддингов
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

  /// Загрузка константных триггеров в базу (вызывается один раз при создании)
  Future<void> _loadConstantTriggers() async {
    final triggers = UefaTriggerConstants.all;
    final points = <Map<String, dynamic>>[];

    for (var i = 0; i < triggers.length; i++) {
      final trigger = triggers[i];
      final vector = _vectorize(trigger);
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
    }
  }

  /// Определение языка фразы
  String _getLanguage(String text) {
    final russianPattern = RegExp(r'[а-яА-ЯёЁ]');
    return russianPattern.hasMatch(text) ? 'ru' : 'en';
  }

  /// Поиск триггера в запросе пользователя
  /// Возвращает найденные триггеры с оценкой схожести
  Future<List<Map<String, dynamic>>> findTriggers(String query,
      {double? threshold}) async {
    final queryVector = _vectorize(query);
    
    final results = await _qdrant.searchPoints(
      collectionName: _collectionName,
      vector: queryVector,
      limit: 5,
    );

    // Фильтрация по порогу схожести
    final effectiveThreshold = threshold ?? _threshold;
    return results
        .where((result) => (result['score'] as num?)?.toDouble() ?? 0 >= effectiveThreshold)
        .toList();
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
}
