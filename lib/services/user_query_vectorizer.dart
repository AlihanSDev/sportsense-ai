import 'dart:convert';

import 'hf_embedding_service.dart';
import 'vector_db_manager.dart';

class UserQueryVectorizerService {
  final VectorDatabaseManager _dbManager;
  final HfEmbeddingService _embeddingService;
  final String _collectionName;
  final Map<int, _QueryData> _recentQueries;
  int _nextQueryId;

  UserQueryVectorizerService({
    required VectorDatabaseManager dbManager,
    HfEmbeddingService? embeddingService,
    String collectionName = 'user_queries_temp',
  }) : _dbManager = dbManager,
       _embeddingService = embeddingService ?? HfEmbeddingService(),
       _collectionName = collectionName,
       _recentQueries = {},
       _nextQueryId = 1;

  Future<void> initialize() async {
    await _dbManager.resetCollection(
      name: _collectionName,
      vectorSize: HfEmbeddingService.vectorSize,
      distanceMetric: 'Cosine',
    );
    print('Query collection initialized: $_collectionName');
  }

  Future<QueryVectorizationResult> vectorizeQuery(String query) async {
    await _clearCollection();
    final vector = await _embeddingService.embed(query);

    final queryId = _nextQueryId++;
    final timestamp = DateTime.now();
    final payload = {
      'query': query,
      'timestamp': timestamp.toIso8601String(),
      'wordCount': query
          .split(RegExp(r'\s+'))
          .where((part) => part.isNotEmpty)
          .length,
      'charCount': query.length,
    };

    final success = await _dbManager.upsert(
      collectionName: _collectionName,
      id: queryId,
      vector: vector,
      payload: payload,
    );

    if (success) {
      _recentQueries[queryId] = _QueryData(
        id: queryId,
        query: query,
        vector: vector,
        timestamp: timestamp,
      );

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

  Future<void> _clearCollection() async {
    _recentQueries.clear();
    await _dbManager.resetCollection(
      name: _collectionName,
      vectorSize: HfEmbeddingService.vectorSize,
      distanceMetric: 'Cosine',
    );
  }

  Future<List<Map<String, dynamic>>?> findSimilarQueries({
    required String query,
    int limit = 5,
  }) async {
    final vector = await _embeddingService.embed(query);

    return _dbManager.search(
      collectionName: _collectionName,
      vector: vector,
      limit: limit,
    );
  }

  _QueryData? getLastQuery() {
    if (_recentQueries.isEmpty) {
      return null;
    }
    return _recentQueries.values.last;
  }

  Map<String, dynamic> get stats {
    return {
      'collectionName': _collectionName,
      'cachedQueries': _recentQueries.length,
      'mode': _dbManager.currentMode,
    };
  }

  Future<void> clearTempData() async {
    _recentQueries.clear();
    await _clearCollection();
    print('Temporary query vectors cleared');
  }
}

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

  String formatVectors({int showFirst = 5, int showLast = 5}) {
    if (vector.isEmpty) {
      return '[]';
    }

    final first = vector
        .take(showFirst)
        .map((v) => v.toStringAsFixed(3))
        .join(', ');
    final last = vector
        .skip(vector.length - showLast)
        .map((v) => v.toStringAsFixed(3))
        .join(', ');

    if (vector.length <= showFirst + showLast) {
      return '[${vector.map((v) => v.toStringAsFixed(3)).join(', ')}]';
    }

    return '[$first, ..., $last]';
  }

  String toJsonString() {
    return json.encode(vector);
  }

  @override
  String toString() {
    return 'QueryVectorizationResult(id: $queryId, query: "$query", mode: $mode, vectorSize: ${vector.length})';
  }
}

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
