import 'dart:convert';
import 'dart:math' show sqrt;

import 'vector_db_manager.dart';

/// Сервис для обработки и векторизации пользовательских запросов.
/// 
/// Временное хранение запросов в отдельной коллекции для тестирования.
class UserQueryVectorizerService {
  final VectorDatabaseManager _dbManager;
  final String _collectionName;
  
  // Кэш для хранения последних запросов в памяти
  final Map<int, _QueryData> _recentQueries;
  int _nextQueryId;

  UserQueryVectorizerService({
    required VectorDatabaseManager dbManager,
    String collectionName = 'user_queries_temp',
  })  : _dbManager = dbManager,
        _collectionName = collectionName,
        _recentQueries = {},
        _nextQueryId = 1;

  /// Инициализация сервиса.
  Future<void> initialize() async {
    // Создаём коллекцию для временных запросов
    await _dbManager.createCollection(
      name: _collectionName,
      vectorSize: 768, // granite-embedding-278m-multilingual
      distanceMetric: 'Cosine',
    );
    print('✓ Коллекция для запросов создана: $_collectionName');
  }

  /// Векторизация пользовательского запроса.
  /// 
  /// Возвращает векторы и сохраняет запрос во временную базу.
  Future<QueryVectorizationResult> vectorizeQuery(String query) async {
    // Генерируем эмбеддинги (пока заглушка - случайные векторы)
    // TODO: Интегрировать с Python-скриптом или ONNX моделью
    final vector = _generateTestEmbeddings(query);

    // Сохраняем во временную базу
    final queryId = _nextQueryId++;
    final timestamp = DateTime.now();

    final payload = {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      'wordCount': query.split(' ').length,
      'charCount': query.length,
    };

    final success = await _dbManager.upsert(
      collectionName: _collectionName,
      id: queryId,
      vector: vector,
      payload: payload,
    );

    if (success) {
      // Сохраняем в кэш
      _recentQueries[queryId] = _QueryData(
        id: queryId,
        query: query,
        vector: vector,
        timestamp: timestamp,
      );

      // Очищаем старые запросы (храним последние 100)
      if (_recentQueries.length > 100) {
        final oldestId = _recentQueries.keys.first;
        _recentQueries.remove(oldestId);
      }
    }

    return QueryVectorizationResult(
      queryId: queryId,
      query: query,
      vector: vector,
      timestamp: timestamp,
      mode: _dbManager.currentMode,
      success: success,
    );
  }

  /// Генерация тестовых эмбеддингов (заглушка).
  /// 
  /// TODO: Заменить на реальную модель эмбеддингов.
  List<double> _generateTestEmbeddings(String query) {
    // Генерируем псевдо-случайный вектор на основе хэша запроса
    final hash = utf8.encode(query);
    final vector = List<double>.filled(768, 0.0);

    for (int i = 0; i < 768; i++) {
      // Детерминированная генерация на основе хэша
      final seed = hash[i % hash.length] ^ (i * 17);
      vector[i] = ((seed % 1000) / 1000.0 - 0.5) * 2; // от -1 до 1
    }

    // Нормализация (для косинусной схожести)
    final norm = _vectorNorm(vector);
    if (norm > 0) {
      for (int i = 0; i < vector.length; i++) {
        vector[i] /= norm;
      }
    }

    return vector;
  }

  /// Норма вектора.
  double _vectorNorm(List<double> vector) {
    double sum = 0.0;
    for (final v in vector) {
      sum += v * v;
    }
    return sqrt(sum);
  }

  /// Поиск похожих запросов.
  Future<List<Map<String, dynamic>>?> findSimilarQueries({
    required String query,
    int limit = 5,
  }) async {
    final vector = _generateTestEmbeddings(query);
    
    return await _dbManager.search(
      collectionName: _collectionName,
      vector: vector,
      limit: limit,
    );
  }

  /// Получение последнего запроса.
  _QueryData? getLastQuery() {
    if (_recentQueries.isEmpty) return null;
    return _recentQueries.values.last;
  }

  /// Статистика.
  Map<String, dynamic> get stats {
    return {
      'collectionName': _collectionName,
      'cachedQueries': _recentQueries.length,
      'mode': _dbManager.currentMode,
    };
  }

  /// Очистка временных данных.
  Future<void> clearTempData() async {
    _recentQueries.clear();
    // TODO: Удалить коллекцию и создать заново
    print('✓ Временные данные очищены');
  }
}

/// Результат векторизации запроса.
class QueryVectorizationResult {
  final int queryId;
  final String query;
  final List<double> vector;
  final DateTime timestamp;
  final String mode;
  final bool success;

  QueryVectorizationResult({
    required this.queryId,
    required this.query,
    required this.vector,
    required this.timestamp,
    required this.mode,
    required this.success,
  });

  /// Форматированный вывод векторов (первые N и последние M).
  String formatVectors({int showFirst = 5, int showLast = 5}) {
    if (vector.isEmpty) return '[]';

    final first = vector.take(showFirst).map((v) => v.toStringAsFixed(3)).join(', ');
    final last = vector.skip(vector.length - showLast).map((v) => v.toStringAsFixed(3)).join(', ');

    if (vector.length <= showFirst + showLast) {
      return '[${vector.map((v) => v.toStringAsFixed(3)).join(', ')}]';
    }

    return '[$first, ..., $last]';
  }

  /// Полный вектор как JSON строка.
  String toJsonString() {
    return json.encode(vector);
  }

  @override
  String toString() {
    return 'QueryVectorizationResult(id: $queryId, query: "$query", mode: $mode, vectorSize: ${vector.length})';
  }
}

/// Данные запроса для кэша.
class _QueryData {
  final int id;
  final String query;
  final List<double> vector;
  final DateTime timestamp;

  _QueryData({
    required this.id,
    required this.query,
    required this.vector,
    required this.timestamp,
  });
}
