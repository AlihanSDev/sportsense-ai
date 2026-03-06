import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';
import 'qdrant_client.dart';

/// Сервис для загрузки триггерных слов из txt файла
/// и чанкования их в Qdrant векторную базу данных.
class TriggerWordsLoader {
  final QdrantClient _qdrant;
  final String _collectionName = 'uefa_triggers';
  final String _assetPath = 'assets/trigger_words.txt';
  
  // Кэш векторов
  final Map<int, List<double>> _vectorCache = {};
  
  // Размерность вектора
  final int _vectorSize = 384;

  TriggerWordsLoader({
    QdrantClient? qdrant,
  }) : _qdrant = qdrant ?? QdrantClient();

  /// Простая хэш-функция для векторизации текста
  List<double> _vectorize(String text) {
    final vector = List<double>.filled(_vectorSize, 0.0);
    final normalizedText = text.toLowerCase().trim();
    
    // Хэширование на основе символов и биграмм
    for (var i = 0; i < normalizedText.length; i++) {
      final charCode = normalizedText.codeUnitAt(i);
      
      // Унарные признаки
      final index1 = (charCode + i) % _vectorSize;
      vector[index1] += 0.5;
      
      // Биграммы
      if (i < normalizedText.length - 1) {
        final nextCode = normalizedText.codeUnitAt(i + 1);
        final bigram = charCode * 31 + nextCode;
        final index2 = bigram.abs() % _vectorSize;
        vector[index2] += 0.3;
      }
    }
    
    // L2 нормализация
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

  /// Загрузка триггеров из txt файла
  Future<List<String>> loadTriggerWords() async {
    try {
      final content = await rootBundle.loadString(_assetPath);
      final lines = content.split('\n');
      final triggers = <String>[];
      
      for (var line in lines) {
        line = line.trim();
        
        // Пропускаем комментарии и пустые строки
        if (line.isEmpty || line.startsWith('#')) continue;
        
        // Пропускаем заголовки секций
        if (line.startsWith('##')) continue;
        
        triggers.add(line);
      }
      
      debugPrint('📄 Загружено ${triggers.length} триггеров из $_assetPath');
      return triggers;
    } catch (e) {
      debugPrint('❌ Ошибка загрузки триггеров: $e');
      return _getDefaultTriggers();
    }
  }

  /// Дефолтный список триггеров (fallback)
  List<String> _getDefaultTriggers() {
    return [
      'ranking', 'rankings', 'uefa ranking', 'uefa rankings',
      'club ranking', 'club rankings', 'team ranking', 'team rankings',
      'uefa table', 'uefa standings', 'coefficient ranking', 'uefa coefficient',
      'рейтинг', 'рейтинги', 'рейтинг клубов', 'рейтинг uefa',
      'таблица uefa', 'коэффициент uefa', 'еврокубковый рейтинг',
    ];
  }

  /// Инициализация Qdrant и загрузка триггеров
  Future<bool> initialize() async {
    // Попытка запуска локального Qdrant
    final qdrantReady = await _qdrant.startLocal();
    
    if (!qdrantReady) {
      debugPrint('⚠️ Qdrant недоступен. Загрузим триггеры позже.');
      return false;
    }

    // Загрузка триггеров из файла
    final triggers = await loadTriggerWords();
    
    if (triggers.isEmpty) {
      debugPrint('❌ Нет триггеров для загрузки');
      return false;
    }

    // Проверка существования коллекции
    final exists = await _qdrant.collectionExists(_collectionName);
    
    if (!exists) {
      // Создаём новую коллекцию
      final created = await _qdrant.createCollection(
        collectionName: _collectionName,
        vectorSize: _vectorSize,
        distance: 'Cosine',
      );
      
      if (!created) {
        debugPrint('❌ Не удалось создать коллекцию');
        return false;
      }
    } else {
      // Коллекция существует - очищаем и перезаписываем
      debugPrint('🔄 Коллекция существует, очищаем...');
      await _qdrant.clearCollection(_collectionName);
    }

    // Загрузка триггеров в Qdrant
    await _uploadTriggers(triggers);
    
    return true;
  }

  /// Загрузка триггеров в Qdrant чанками
  Future<void> _uploadTriggers(List<String> triggers) async {
    const chunkSize = 100; // Загружаем по 100 записей за раз
    
    for (var i = 0; i < triggers.length; i += chunkSize) {
      final end = (i + chunkSize < triggers.length) 
          ? i + chunkSize 
          : triggers.length;
      
      final chunk = triggers.sublist(i, end);
      final points = <Map<String, dynamic>>[];
      
      for (var j = 0; j < chunk.length; j++) {
        final index = i + j;
        final trigger = chunk[j];
        final vector = _vectorize(trigger);
        _vectorCache[index] = vector; // Кэшируем
        
        points.add({
          'id': index,
          'vector': vector,
          'payload': {
            'text': trigger,
            'language': _getLanguage(trigger),
            'source': 'assets/trigger_words.txt',
            'is_constant': true,
          },
        });
      }
      
      if (points.isNotEmpty) {
        final success = await _qdrant.upsertPoints(
          collectionName: _collectionName,
          points: points,
        );
        
        if (success) {
          debugPrint('📦 Загружен чанк ${i + 1}-${end} из ${triggers.length}');
        } else {
          debugPrint('❌ Ошибка загрузки чанка ${i + 1}-${end}');
        }
      }
      
      // Небольшая задержка между чанками
      if (end < triggers.length) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    
    debugPrint('✅ Загружено ${triggers.length} триггеров в Qdrant');
  }

  /// Определение языка фразы
  String _getLanguage(String text) {
    final russianPattern = RegExp(r'[а-яА-ЯёЁ]');
    return russianPattern.hasMatch(text) ? 'ru' : 'en';
  }

  /// Поиск похожих триггеров в Qdrant
  Future<List<Map<String, dynamic>>> searchSimilar(
    String query, {
    int limit = 5,
    double threshold = 0.5,
  }) async {
    final queryVector = _vectorize(query);
    
    final results = await _qdrant.searchPoints(
      collectionName: _collectionName,
      vector: queryVector,
      limit: limit,
      threshold: threshold,
    );
    
    return results;
  }

  /// Проверка наличия триггера
  Future<bool> hasTrigger(String query, {double threshold = 0.5}) async {
    final results = await searchSimilar(query, threshold: threshold);
    return results.isNotEmpty;
  }

  /// Получить количество триггеров в коллекции
  Future<int> getTriggerCount() async {
    try {
      final info = await _qdrant.getCollectionInfo(_collectionName);
      if (info != null) {
        final pointsCount = info['points_count'] as int?;
        return pointsCount ?? 0;
      }
    } catch (e) {
      // Игнорируем ошибки
    }
    return 0;
  }

  /// Очистка коллекции
  Future<bool> clear() async {
    return await _qdrant.clearCollection(_collectionName);
  }

  /// Перезагрузка триггеров
  Future<bool> reload() async {
    await clear();
    return await initialize();
  }

  /// Остановка Qdrant
  Future<void> dispose() async {
    await _qdrant.dispose();
  }
}
