import 'dart:math' show sqrt;
import 'vector_db_manager.dart';

/// Сервис для поиска релевантных данных в векторной базе UEFA Rankings.
/// Реализует RAG (Retrieval Augmented Generation) паттерн.
class RankingsVectorSearch {
  final VectorDatabaseManager _dbManager;
  final String _collectionName;

  RankingsVectorSearch({
    required VectorDatabaseManager dbManager,
    String collectionName = 'uefa_rankings_embeddings',
  })  : _dbManager = dbManager,
        _collectionName = collectionName;

  /// Поиск релевантных данных рейтинга по запросу.
  /// Возвращает данные для передачи в LLM как контекст.
  Future<List<Map<String, dynamic>>?> searchRankings(String query, {
    int limit = 10,
  }) async {
    print('🔍 RAG: Поиск по запросу: "$query"');
    
    // Генерируем эмбеддинг для запроса
    final queryVector = _generateQueryEmbedding(query);
    print('📊 RAG: Вектор запроса сгенерирован (${queryVector.length} dim)');

    // Поиск в векторной базе
    final results = await _dbManager.search(
      collectionName: _collectionName,
      vector: queryVector,
      limit: limit,
    );

    if (results == null || results.isEmpty) {
      print('⚠️ RAG: Ничего не найдено в векторной базе');
      return null;
    }

    print('✅ RAG: Найдено ${results.length} записей');
    
    // Логируем найденные результаты
    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      final score = result['score'] as double?;
      final payload = result['payload'] as Map<String, dynamic>?;
      final association = payload?['association'] ?? 'Unknown';
      final rank = payload?['rank'] ?? '?';
      print('   #$rank: $association (score: ${score?.toStringAsFixed(3) ?? "N/A"})');
    }

    return results;
  }

  /// Форматирование результатов для передачи в LLM (RAG контекст).
  String formatContext(List<Map<String, dynamic>>? results) {
    if (results == null || results.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('=== UEFA RANKINGS DATA (from vector database) ===');
    buffer.writeln('The following data was retrieved from the UEFA rankings database:');
    buffer.writeln('');

    // Сортируем по рангу
    final sortedResults = List<Map<String, dynamic>>.from(results);
    sortedResults.sort((a, b) {
      final rankA = int.tryParse((a['payload'] as Map<String, dynamic>?)?['rank'] ?? '999') ?? 999;
      final rankB = int.tryParse((b['payload'] as Map<String, dynamic>?)?['rank'] ?? '999') ?? 999;
      return rankA.compareTo(rankB);
    });

    for (final result in sortedResults) {
      final payload = result['payload'] as Map<String, dynamic>?;
      if (payload != null) {
        final rank = payload['rank'] ?? '?';
        final association = payload['association'] ?? payload['col_0'] ?? 'Unknown';
        final clubs = payload['clubs'] ?? payload['col_1'] ?? '';
        final points = payload['points'] ?? payload['col_3'] ?? '';
        final bonus = payload['bonus'] ?? payload['col_2'] ?? '';
        final avg = payload['avg'] ?? payload['col_4'] ?? '';
        final rawText = payload['raw_text'] ?? '';

        buffer.writeln('Rank #$rank: $association');
        if (clubs.isNotEmpty) buffer.writeln('  - Clubs: $clubs');
        if (points.isNotEmpty) buffer.writeln('  - Total Points: $points');
        if (bonus.isNotEmpty) buffer.writeln('  - Bonus Points: $bonus');
        if (avg.isNotEmpty) buffer.writeln('  - Average: $avg');
        if (rawText.isNotEmpty) {
          buffer.writeln('  - Context: $rawText');
        }
        buffer.writeln('');
      }
    }

    buffer.writeln('=== END OF UEFA RANKINGS DATA ===');
    buffer.writeln('');
    buffer.writeln('Use this data to answer the user\'s question about UEFA rankings.');
    buffer.writeln('If the user asks about specific teams, positions, or points, refer to this data.');

    return buffer.toString();
  }

  /// Получение полного контекста для RAG.
  Future<String> getRagContext(String query, {int limit = 10}) async {
    final results = await searchRankings(query, limit: limit);
    return formatContext(results);
  }

  /// Генерация эмбеддинга для запроса.
  /// TODO: Использовать реальную модель (granite-embedding-278m-multilingual)
  List<double> _generateQueryEmbedding(String query) {
    // Используем тот же алгоритм что и при сохранении
    final hash = query.codeUnits;
    final vector = List<double>.filled(768, 0.0);

    for (int i = 0; i < 768; i++) {
      final seed = hash[i % hash.length] ^ (i * 17);
      vector[i] = ((seed % 1000) / 1000.0 - 0.5) * 2;
    }

    // Нормализация для косинусной схожести
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
}
