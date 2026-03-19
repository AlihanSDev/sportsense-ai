import 'dart:convert';
import 'package:http/http.dart' as http;

/// Конфигурация Qdrant из переменных окружения.
class QdrantConfig {
  final String host;
  final int port;
  final int grpcPort;
  final String? apiKey;
  final String collectionRankings;
  final String collectionMatches;
  final int vectorSize;
  final String distanceMetric;

  QdrantConfig({
    required this.host,
    required this.port,
    this.grpcPort = 6334,
    this.apiKey,
    this.collectionRankings = 'uefa_rankings_embeddings',
    this.collectionMatches = 'uefa_matches_embeddings',
    this.vectorSize = 768,
    this.distanceMetric = 'Cosine',
  });

  String get baseUrl => 'http://$host:$port';

  Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
  };

  /// Создаёт конфигурацию из переменных окружения.
  factory QdrantConfig.fromEnv() {
    return QdrantConfig(
      host: const String.fromEnvironment(
        'QDRANT_HOST',
        defaultValue: 'localhost',
      ),
      port:
          int.tryParse(
            const String.fromEnvironment('QDRANT_PORT', defaultValue: '6333'),
          ) ??
          6333,
      grpcPort:
          int.tryParse(
            const String.fromEnvironment(
              'QDRANT_GRPC_PORT',
              defaultValue: '6334',
            ),
          ) ??
          6334,
      apiKey: const String.fromEnvironment('QDRANT_API_KEY', defaultValue: ''),
      collectionRankings: const String.fromEnvironment(
        'QDRANT_COLLECTION_RANKINGS',
        defaultValue: 'uefa_rankings_embeddings',
      ),
      collectionMatches: const String.fromEnvironment(
        'QDRANT_COLLECTION_MATCHES',
        defaultValue: 'uefa_matches_embeddings',
      ),
      vectorSize:
          int.tryParse(
            const String.fromEnvironment(
              'QDRANT_VECTOR_SIZE',
              defaultValue: '768',
            ),
          ) ??
          768,
      distanceMetric: const String.fromEnvironment(
        'QDRANT_DISTANCE_METRIC',
        defaultValue: 'Cosine',
      ),
    );
  }

  @override
  String toString() {
    return 'QdrantConfig(host: $host, port: $port, collections: [$collectionRankings, $collectionMatches], vectorSize: $vectorSize)';
  }
}

/// Тип расстояния для векторного поиска.
enum QdrantDistanceType { cosine, euclid, dot }

extension QdrantDistanceTypeExt on QdrantDistanceType {
  String get value {
    switch (this) {
      case QdrantDistanceType.cosine:
        return 'Cosine';
      case QdrantDistanceType.euclid:
        return 'Euclid';
      case QdrantDistanceType.dot:
        return 'Dot';
    }
  }

  static QdrantDistanceType fromString(String value) {
    return QdrantDistanceType.values.firstWhere(
      (e) => e.value.toLowerCase() == value.toLowerCase(),
      orElse: () => QdrantDistanceType.cosine,
    );
  }
}

/// Сервис для работы с Qdrant vector database.
///
/// Предоставляет базовый функционал:
/// - Проверка доступности Qdrant
/// - Создание коллекций
/// - Поиск по векторам
/// - Добавление точек (points)
class QdrantService {
  final QdrantConfig config;
  final http.Client _client;

  QdrantService({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  /// Проверка доступности Qdrant.
  Future<bool> isAvailable() async {
    try {
      final response = await _client
          .get(Uri.parse('${config.baseUrl}/'), headers: config.headers)
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Получение информации о кластере.
  Future<Map<String, dynamic>?> getClusterInfo() async {
    try {
      final response = await _client.get(
        Uri.parse('${config.baseUrl}/cluster'),
        headers: config.headers,
      );
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error getting cluster info: $e');
    }
    return null;
  }

  /// Создание коллекции.
  Future<bool> createCollection({
    required String collectionName,
    required int vectorSize,
    String distance = 'Cosine',
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('${config.baseUrl}/collections/$collectionName'),
        headers: config.headers,
        body: json.encode({
          'vectors': {'size': vectorSize, 'distance': distance},
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error creating collection $collectionName: $e');
      return false;
    }
  }

  /// Проверка существования коллекции.
  Future<bool> collectionExists(String collectionName) async {
    try {
      final response = await _client.get(
        Uri.parse('${config.baseUrl}/collections/$collectionName'),
        headers: config.headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Создание коллекций по умолчанию.
  Future<void> createDefaultCollections() async {
    if (!await collectionExists(config.collectionRankings)) {
      await createCollection(
        collectionName: config.collectionRankings,
        vectorSize: config.vectorSize,
        distance: config.distanceMetric,
      );
      print('Created collection: ${config.collectionRankings}');
    }

    if (!await collectionExists(config.collectionMatches)) {
      await createCollection(
        collectionName: config.collectionMatches,
        vectorSize: config.vectorSize,
        distance: config.distanceMetric,
      );
      print('Created collection: ${config.collectionMatches}');
    }
  }

  /// Добавление точки (point) в коллекцию.
  Future<bool> upsertPoint({
    required String collectionName,
    required int id,
    required List<double> vector,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('${config.baseUrl}/collections/$collectionName/points'),
        headers: config.headers,
        body: json.encode({
          'points': [
            {'id': id, 'vector': vector, 'payload': ?payload},
          ],
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error upserting point: $e');
      return false;
    }
  }

  /// Поиск по вектору.
  Future<List<Map<String, dynamic>>?> search({
    required String collectionName,
    required List<double> vector,
    int limit = 10,
    Map<String, dynamic>? filter,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse(
          '${config.baseUrl}/collections/$collectionName/points/search',
        ),
        headers: config.headers,
        body: json.encode({
          'vector': vector,
          'limit': limit,
          'filter': ?filter,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return (data['result'] as List).cast<Map<String, dynamic>>();
      }
    } catch (e) {
      print('Error searching: $e');
    }
    return null;
  }

  /// Удаление коллекции.
  Future<bool> deleteCollection(String collectionName) async {
    try {
      final response = await _client.delete(
        Uri.parse('${config.baseUrl}/collections/$collectionName'),
        headers: config.headers,
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting collection $collectionName: $e');
      return false;
    }
  }

  /// Получение информации о коллекции.
  Future<Map<String, dynamic>?> getCollectionInfo(String collectionName) async {
    try {
      final response = await _client.get(
        Uri.parse('${config.baseUrl}/collections/$collectionName'),
        headers: config.headers,
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['result'] as Map<String, dynamic>?;
      }
    } catch (e) {
      print('Error getting collection info: $e');
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}
