import 'hf_embedding_service.dart';
import 'rankings_context_interpreter.dart';
import 'vector_db_manager.dart';

class RankingsVectorSearch {
  final VectorDatabaseManager _dbManager;
  final HfEmbeddingService _embeddingService;
  final RankingsContextInterpreter _interpreter;
  final String _collectionName;

  RankingsVectorSearch({
    required VectorDatabaseManager dbManager,
    HfEmbeddingService? embeddingService,
    RankingsContextInterpreter? interpreter,
    String collectionName = 'uefa_rankings_embeddings',
  }) : _dbManager = dbManager,
       _embeddingService = embeddingService ?? HfEmbeddingService(),
       _interpreter = interpreter ?? RankingsContextInterpreter(),
       _collectionName = collectionName;

  Future<List<Map<String, dynamic>>?> searchRankings(
    String query, {
    int limit = 10,
  }) async {
    if (query.trim().isEmpty) {
      return null;
    }

    print('RAG search query: "$query"');
    final queryVector = await _embeddingService.embed(query);

    final results = await _dbManager.search(
      collectionName: _collectionName,
      vector: queryVector,
      limit: limit,
    );

    if (results == null || results.isEmpty) {
      print('RAG search returned no vector matches');
      return null;
    }

    final candidateTexts = results.map((result) {
      final payload = Map<String, dynamic>.from(
        result['payload'] as Map<String, dynamic>? ?? const {},
      );
      return (payload['canonical_text'] ?? payload['raw_text'] ?? '')
          .toString();
    }).toList();

    final similarityScores = await _embeddingService.sentenceSimilarity(
      sourceSentence: query,
      sentences: candidateTexts,
    );

    final enrichedResults = <Map<String, dynamic>>[];
    for (int i = 0; i < results.length; i++) {
      final result = Map<String, dynamic>.from(results[i]);
      final vectorScore = (result['score'] as num?)?.toDouble() ?? 0;
      final semanticScore =
          similarityScores != null && i < similarityScores.length
          ? similarityScores[i]
          : vectorScore;
      final combinedScore = (vectorScore * 0.55) + (semanticScore * 0.45);

      result['vectorScore'] = vectorScore;
      result['semanticScore'] = semanticScore;
      result['combinedScore'] = combinedScore;
      enrichedResults.add(result);
    }

    enrichedResults.sort((a, b) {
      final scoreA = (a['combinedScore'] as num?)?.toDouble() ?? 0;
      final scoreB = (b['combinedScore'] as num?)?.toDouble() ?? 0;
      return scoreB.compareTo(scoreA);
    });

    return enrichedResults;
  }

  RankingsInterpretation interpretResults({
    required String query,
    required List<Map<String, dynamic>> results,
  }) {
    return _interpreter.interpret(query: query, results: results);
  }

  Future<String> getRagContext(String query, {int limit = 10}) async {
    final results = await searchRankings(query, limit: limit);
    if (results == null || results.isEmpty) {
      return '';
    }

    final interpretation = interpretResults(query: query, results: results);
    return interpretation.context;
  }
}
