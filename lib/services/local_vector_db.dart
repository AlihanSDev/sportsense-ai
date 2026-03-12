import 'dart:convert';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart' show kIsWeb;

// Импорт для работы с localStorage (только web)
import 'dart:html' as html_web;

/// Точка данных в локальной векторной базе.
class LocalVectorPoint {
  final int id;
  final List<double> vector;
  final Map<String, dynamic> payload;

  LocalVectorPoint({
    required this.id,
    required this.vector,
    Map<String, dynamic>? payload,
  }) : payload = payload ?? {};

  Map<String, dynamic> toJson() => {
    'id': id,
    'vector': vector,
    'payload': payload,
  };

  factory LocalVectorPoint.fromJson(Map<String, dynamic> json) {
    return LocalVectorPoint(
      id: json['id'] as int,
      vector: (json['vector'] as List).cast<double>(),
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
    );
  }
}

/// Коллекция в локальной векторной базе.
class LocalVectorCollection {
  final String name;
  final int vectorSize;
  final String distanceMetric;
  final Map<int, LocalVectorPoint> _points;

  LocalVectorCollection({
    required this.name,
    required this.vectorSize,
    this.distanceMetric = 'Cosine',
  }) : _points = {};

  /// Добавление точки.
  void upsert(LocalVectorPoint point) {
    if (point.vector.length != vectorSize) {
      throw ArgumentError(
        'Vector size ${point.vector.length} does not match collection size $vectorSize',
      );
    }
    _points[point.id] = point;
  }

  /// Удаление точки по ID.
  bool delete(int id) {
    return _points.remove(id) != null;
  }

  /// Получение точки по ID.
  LocalVectorPoint? get(int id) {
    return _points[id];
  }

  /// Поиск ближайших соседей.
  List<_ScoredPoint> search(List<double> vector, {int limit = 10}) {
    if (vector.length != vectorSize) {
      throw ArgumentError(
        'Vector size ${vector.length} does not match collection size $vectorSize',
      );
    }

    final scored = <_ScoredPoint>[];
    for (final point in _points.values) {
      final score = _calculateSimilarity(vector, point.vector);
      scored.add(_ScoredPoint(point: point, score: score));
    }

    // Сортировка по убыванию схожести
    scored.sort((a, b) => b.score.compareTo(a.score));

    return scored.take(limit).toList();
  }

  /// Расчёт схожести векторов.
  double _calculateSimilarity(List<double> a, List<double> b) {
    switch (distanceMetric.toLowerCase()) {
      case 'cosine':
        return _cosineSimilarity(a, b);
      case 'euclid':
        return _euclideanDistance(a, b);
      case 'dot':
        return _dotProduct(a, b);
      default:
        return _cosineSimilarity(a, b);
    }
  }

  /// Косинусная схожесть.
  double _cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Евклидово расстояние (преобразовано в схожесть).
  double _euclideanDistance(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      final diff = a[i] - b[i];
      sum += diff * diff;
    }
    // Преобразуем расстояние в схожесть (чем меньше расстояние, тем больше схожесть)
    return 1.0 / (1.0 + sqrt(sum));
  }

  /// Скалярное произведение.
  double _dotProduct(List<double> a, List<double> b) {
    double sum = 0.0;
    for (int i = 0; i < a.length; i++) {
      sum += a[i] * b[i];
    }
    return sum;
  }

  /// Количество точек.
  int get count => _points.length;

  /// Все точки.
  List<LocalVectorPoint> get allPoints => _points.values.toList();

  /// Очистка коллекции.
  void clear() {
    _points.clear();
  }

  /// Сериализация в JSON.
  Map<String, dynamic> toJson() => {
    'name': name,
    'vectorSize': vectorSize,
    'distanceMetric': distanceMetric,
    'points': _points.values.map((p) => p.toJson()).toList(),
  };

  /// Десериализация из JSON.
  factory LocalVectorCollection.fromJson(Map<String, dynamic> json) {
    final collection = LocalVectorCollection(
      name: json['name'] as String,
      vectorSize: json['vectorSize'] as int,
      distanceMetric: json['distanceMetric'] as String,
    );
    final points = json['points'] as List? ?? [];
    for (final p in points) {
      final point = LocalVectorPoint.fromJson(p as Map<String, dynamic>);
      collection._points[point.id] = point;
    }
    return collection;
  }
}

/// Точка с оценкой схожести.
class _ScoredPoint {
  final LocalVectorPoint point;
  final double score;

  _ScoredPoint({required this.point, required this.score});

  Map<String, dynamic> toJson() => {'point': point.toJson(), 'score': score};
}

/// Локальная векторная база данных (Plan B fallback).
///
/// Хранит данные в памяти с возможностью сохранения на диск.
/// Используется как запасной вариант при отсутствии Qdrant.
class LocalVectorDatabase {
  final String _storagePath;
  final Map<String, LocalVectorCollection> _collections;
  int _nextId;

  LocalVectorDatabase({String? storagePath})
    : _storagePath = storagePath ?? 'data/vector_db',
      _collections = {},
      _nextId = 1;

  /// Инициализация базы данных.
  Future<void> initialize() async {
    await _loadFromDisk();
  }

  /// Создание коллекции.
  LocalVectorCollection createCollection({
    required String name,
    required int vectorSize,
    String distanceMetric = 'Cosine',
  }) {
    if (_collections.containsKey(name)) {
      throw ArgumentError('Collection "$name" already exists');
    }

    final collection = LocalVectorCollection(
      name: name,
      vectorSize: vectorSize,
      distanceMetric: distanceMetric,
    );
    _collections[name] = collection;
    return collection;
  }

  /// Получение коллекции.
  LocalVectorCollection? getCollection(String name) {
    return _collections[name];
  }

  /// Проверка существования коллекции.
  bool collectionExists(String name) {
    return _collections.containsKey(name);
  }

  /// Удаление коллекции.
  bool deleteCollection(String name) {
    return _collections.remove(name) != null;
  }

  void resetCollection({
    required String name,
    required int vectorSize,
    String distanceMetric = 'Cosine',
  }) {
    _collections.remove(name);
    _collections[name] = LocalVectorCollection(
      name: name,
      vectorSize: vectorSize,
      distanceMetric: distanceMetric,
    );
  }

  /// Список всех коллекций.
  List<String> get collectionNames => _collections.keys.toList();

  /// Добавление точки в коллекцию.
  bool upsert({
    required String collectionName,
    int? id,
    required List<double> vector,
    Map<String, dynamic>? payload,
  }) {
    final collection = _collections[collectionName];
    if (collection == null) return false;

    final pointId = id ?? _nextId++;
    final point = LocalVectorPoint(
      id: pointId,
      vector: vector,
      payload: payload,
    );
    collection.upsert(point);
    return true;
  }

  /// Поиск по коллекции.
  List<Map<String, dynamic>>? search({
    required String collectionName,
    required List<double> vector,
    int limit = 10,
  }) {
    final collection = _collections[collectionName];
    if (collection == null) return null;

    final results = collection.search(vector, limit: limit);
    return results
        .map(
          (r) => {
            'id': r.point.id,
            'score': r.score,
            'payload': r.point.payload,
          },
        )
        .toList();
  }

  /// Сохранение на диск.
  Future<void> saveToDisk() async {
    if (kIsWeb) {
      // Для веба используем localStorage
      final data = {
        'nextId': _nextId,
        'collections': _collections.values.map((c) => c.toJson()).toList(),
      };
      html_web.window.localStorage['vector_db'] = json.encode(data);
      return;
    }

    // Для не-web платформ (Android, iOS, Desktop)
    // Примечание: требует dart:io который не работает в вебе
    throw UnsupportedError(
      'saveToDisk not supported on web. Use localStorage instead.',
    );
  }

  /// Загрузка с диска.
  Future<void> _loadFromDisk() async {
    if (kIsWeb) {
      // Для веба используем localStorage
      try {
        final stored = html_web.window.localStorage['vector_db'];
        if (stored == null) return;

        final data = json.decode(stored) as Map<String, dynamic>;
        _nextId = data['nextId'] as int? ?? 1;

        final collections = data['collections'] as List? ?? [];
        for (final c in collections) {
          final collection = LocalVectorCollection.fromJson(
            c as Map<String, dynamic>,
          );
          _collections[collection.name] = collection;
        }
      } catch (e) {
        print('Error loading vector database from localStorage: $e');
      }
      return;
    }

    // Для не-web платформ
    throw UnsupportedError(
      '_loadFromDisk not supported on web. Use localStorage instead.',
    );
  }

  /// Очистка всех данных.
  void clear() {
    _collections.clear();
    _nextId = 1;
  }

  /// Статистика базы данных.
  Map<String, dynamic> get stats => {
    'collections': collectionNames.length,
    'totalPoints': _collections.values.fold<int>(0, (sum, c) => sum + c.count),
    'collectionDetails': {
      for (final entry in _collections.entries) entry.key: entry.value.count,
    },
  };

  @override
  String toString() {
    return 'LocalVectorDatabase(collections: ${collectionNames.length}, path: $_storagePath)';
  }
}
