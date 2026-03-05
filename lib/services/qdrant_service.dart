import 'qdrant_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class QdrantService {
  late QdrantClient _client;
  static const String _sportsCollection = 'sports_embeddings';

  QdrantService() {
    final baseUrl = dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333';
    final apiKey = dotenv.env['QDRANT_API_KEY'];
    _client = QdrantClient(baseUrl: baseUrl, apiKey: apiKey);
  }

  /// Инициализация коллекции для спортивных данных
  Future<void> initializeSportsCollection() async {
    final exists = await _client.collectionExists(_sportsCollection);
    if (!exists) {
      await _client.createCollection(
        collectionName: _sportsCollection,
        vectorSize: 1536, // Размер векторов для text-embedding-3-small
        distance: 'Cosine',
      );
    }
  }

  /// Добавление спортивного контента в базу
  Future<bool> addSportsContent({
    required String id,
    required List<double> embedding,
    required String content,
    String? category,
    String? sportType,
  }) async {
    return await _client.upsertPoint(
      collectionName: _sportsCollection,
      id: id,
      vector: embedding,
      payload: {
        'content': content,
        'category': category,
        'sport_type': sportType,
        'created_at': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Поиск похожего спортивного контента
  Future<List<Map<String, dynamic>>> searchSimilar({
    required List<double> embedding,
    int limit = 5,
    String? sportType,
  }) async {
    Map<String, dynamic>? filter;
    if (sportType != null) {
      filter = {
        'must': [
          {'key': 'sport_type', 'match': {'value': sportType}},
        ],
      };
    }

    return await _client.search(
      collectionName: _sportsCollection,
      vector: embedding,
      limit: limit,
      filter: filter,
    );
  }

  /// Получение информации о коллекции
  Future<Map<String, dynamic>?> getCollectionInfo() async {
    return await _client.getCollectionInfo(_sportsCollection);
  }

  /// Удаление коллекции
  Future<bool> deleteCollection() async {
    return await _client.deleteCollection(_sportsCollection);
  }
}
