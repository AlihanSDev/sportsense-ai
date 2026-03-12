class RankingsInterpretation {
  final List<Map<String, dynamic>> rankedResults;
  final String context;
  final String summary;
  final bool hasExactAssociationMatch;

  const RankingsInterpretation({
    required this.rankedResults,
    required this.context,
    required this.summary,
    required this.hasExactAssociationMatch,
  });
}

class RankingsContextInterpreter {
  RankingsInterpretation interpret({
    required String query,
    required List<Map<String, dynamic>> results,
  }) {
    if (results.isEmpty) {
      return const RankingsInterpretation(
        rankedResults: [],
        context: '',
        summary: 'No ranking records were retrieved.',
        hasExactAssociationMatch: false,
      );
    }

    final normalizedQuery = query.toLowerCase();
    final rankedResults = List<Map<String, dynamic>>.from(results)
      ..sort((a, b) {
        final scoreA = (a['combinedScore'] as num?)?.toDouble() ?? 0;
        final scoreB = (b['combinedScore'] as num?)?.toDouble() ?? 0;
        return scoreB.compareTo(scoreA);
      });

    bool hasExactAssociationMatch = false;
    final exactMatches = <String>[];
    final buffer = StringBuffer();

    buffer.writeln('UEFA rankings retrieval summary');
    buffer.writeln('User query: $query');
    buffer.writeln('');

    for (int i = 0; i < rankedResults.length; i++) {
      final result = rankedResults[i];
      final payload = Map<String, dynamic>.from(
        result['payload'] as Map<String, dynamic>? ?? const {},
      );
      final association = (payload['association'] ?? 'Unknown').toString();
      final rank = (payload['rank'] ?? '?').toString();
      final points = (payload['points'] ?? '').toString();
      final clubs = (payload['clubs'] ?? '').toString();
      final avg = (payload['avg'] ?? '').toString();
      final canonicalText =
          (payload['canonical_text'] ?? payload['raw_text'] ?? '').toString();
      final vectorScore = ((result['vectorScore'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(3);
      final semanticScore = ((result['semanticScore'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(3);
      final combinedScore = ((result['combinedScore'] as num?)?.toDouble() ?? 0)
          .toStringAsFixed(3);

      final associationLower = association.toLowerCase();
      if (associationLower.isNotEmpty &&
          normalizedQuery.contains(associationLower)) {
        hasExactAssociationMatch = true;
        exactMatches.add(association);
      }

      buffer.writeln('${i + 1}. $association');
      buffer.writeln('rank: $rank');
      if (points.isNotEmpty) {
        buffer.writeln('points: $points');
      }
      if (avg.isNotEmpty) {
        buffer.writeln('average: $avg');
      }
      if (clubs.isNotEmpty) {
        buffer.writeln('clubs: $clubs');
      }
      buffer.writeln('vector_score: $vectorScore');
      buffer.writeln('semantic_score: $semanticScore');
      buffer.writeln('combined_score: $combinedScore');
      if (canonicalText.isNotEmpty) {
        buffer.writeln('record: $canonicalText');
      }
      buffer.writeln('');
    }

    if (exactMatches.isNotEmpty) {
      buffer.writeln('Exact association matches: ${exactMatches.join(', ')}');
      buffer.writeln('');
    }

    buffer.writeln(
      'Use the ranking numbers above directly. If multiple records are returned, prefer exact association matches and then the highest combined_score.',
    );

    final topPayload = Map<String, dynamic>.from(
      rankedResults.first['payload'] as Map<String, dynamic>? ?? const {},
    );
    final topAssociation = (topPayload['association'] ?? 'Unknown').toString();
    final topRank = (topPayload['rank'] ?? '?').toString();
    final summary = hasExactAssociationMatch
        ? 'Found an exact association match in the ranking data.'
        : 'Top retrieved ranking record: $topAssociation at rank $topRank.';

    return RankingsInterpretation(
      rankedResults: rankedResults,
      context: buffer.toString().trim(),
      summary: summary,
      hasExactAssociationMatch: hasExactAssociationMatch,
    );
  }
}
