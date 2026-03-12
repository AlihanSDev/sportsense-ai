import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:html/parser.dart';
import 'package:http/http.dart' as http;

import 'hf_embedding_service.dart';
import 'uefa_rankings_api_service.dart';
import 'vector_db_manager.dart';

class UefaParser {
  final http.Client _client;
  final String _storagePath;
  final VectorDatabaseManager? _vectorDbManager;
  final UefaRankingsApiService? _rankingsApi;
  final HfEmbeddingService _embeddingService;

  UefaParser({
    http.Client? client,
    String storagePath = 'data/rankings',
    VectorDatabaseManager? vectorDbManager,
    UefaRankingsApiService? rankingsApi,
    HfEmbeddingService? embeddingService,
  }) : _client = client ?? http.Client(),
       _storagePath = storagePath,
       _vectorDbManager = vectorDbManager,
       _rankingsApi = rankingsApi,
       _embeddingService = embeddingService ?? HfEmbeddingService();

  Future<List<String>> fetchRecentMatches() async {
    final uri = Uri.parse('https://www.uefa.com');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Failed to load UEFA homepage: ${resp.statusCode}');
    }

    final document = parse(resp.body);
    final results = <String>{};

    for (final element in document.querySelectorAll(
      'li, .match-row, .match-item',
    )) {
      final text = element.text.trim();
      if (_looksLikeMatch(text)) {
        results.add(text.replaceAll(RegExp(r'\s+'), ' '));
      }
    }

    if (results.isEmpty) {
      for (final anchor in document.querySelectorAll('a')) {
        final text = anchor.text.trim();
        if (_looksLikeMatch(text)) {
          results.add(text.replaceAll(RegExp(r'\s+'), ' '));
        }
      }
    }

    return results.toList();
  }

  Future<List<Map<String, String>>> fetchRankings() async {
    if (_rankingsApi != null) {
      print('Requesting rankings through UEFA Rankings API...');
      final response = await _rankingsApi.getFreshRankings();

      if (response != null && response.data.isNotEmpty) {
        print('UEFA Rankings API returned ${response.data.length} rows');
        return response.data;
      }

      print('UEFA Rankings API unavailable, falling back to HTML parsing');
    }

    return _fetchRankingsHttp();
  }

  Future<String?> parseAndSaveRankings() async {
    try {
      print('Starting UEFA rankings parsing');
      final rankings = await fetchRankings();

      if (rankings.isEmpty) {
        print('No UEFA ranking rows found');
        return null;
      }

      if (_vectorDbManager != null) {
        await _saveToVectorDb(rankings);
      }

      final content = _formatRankingsToTxt(rankings);
      final filePath = await _saveToFile(content);
      print('UEFA rankings prepared at $filePath');
      return filePath;
    } catch (e) {
      print('UEFA rankings parsing failed: $e');
      return null;
    }
  }

  Future<void> _saveToVectorDb(List<Map<String, String>> rankings) async {
    if (_vectorDbManager == null) {
      return;
    }

    const collectionName = 'uefa_rankings_embeddings';
    await _vectorDbManager!.resetCollection(
      name: collectionName,
      vectorSize: HfEmbeddingService.vectorSize,
      distanceMetric: 'Cosine',
    );

    final texts = rankings.asMap().entries.map((entry) {
      return _formatRowForEmbedding(entry.key + 1, entry.value);
    }).toList();

    final embeddings = await _embeddingService.embedBatch(texts);
    int savedCount = 0;

    for (int i = 0; i < rankings.length; i++) {
      final row = rankings[i];
      final payload = _buildPayload(
        rank: i + 1,
        row: row,
        canonicalText: texts[i],
      );
      final success = await _vectorDbManager!.upsert(
        collectionName: collectionName,
        id: i + 1,
        vector: embeddings[i],
        payload: payload,
      );

      if (success) {
        savedCount++;
      }
    }

    print(
      'Stored $savedCount of ${rankings.length} UEFA ranking rows in vector DB',
    );
  }

  Map<String, dynamic> _buildPayload({
    required int rank,
    required Map<String, String> row,
    required String canonicalText,
  }) {
    final association = row['association'] ?? row['col_0'] ?? '';
    final clubs = row['clubs'] ?? row['col_1'] ?? '';
    final bonus = row['bonus'] ?? row['col_2'] ?? '';
    final points = row['points'] ?? row['col_3'] ?? '';
    final avg = row['avg'] ?? row['col_4'] ?? '';

    return {
      'type': 'uefa_ranking',
      'rank': rank.toString(),
      'association': association,
      'association_lower': association.toLowerCase(),
      'clubs': clubs,
      'bonus': bonus,
      'points': points,
      'avg': avg,
      'timestamp': DateTime.now().toIso8601String(),
      'canonical_text': canonicalText,
      'raw_text': canonicalText,
      'source': _rankingsApi != null ? 'uefa_rankings_api' : 'uefa_html_parser',
    };
  }

  String _formatRowForEmbedding(int rank, Map<String, String> row) {
    final association = row['association'] ?? row['col_0'] ?? 'Unknown';
    final clubs = row['clubs'] ?? row['col_1'] ?? '';
    final bonus = row['bonus'] ?? row['col_2'] ?? '';
    final points = row['points'] ?? row['col_3'] ?? '';
    final avg = row['avg'] ?? row['col_4'] ?? '';

    return 'UEFA club ranking row. Rank $rank. Association $association. Clubs $clubs. Bonus points $bonus. Total points $points. Average coefficient $avg.';
  }

  Future<List<Map<String, String>>> _fetchRankingsHttp() async {
    try {
      final uri = Uri.parse(
        'https://www.uefa.com/nationalassociations/uefarankings/club/',
      );
      final resp = await _client.get(uri);

      if (resp.statusCode != 200) {
        print('UEFA rankings HTTP status: ${resp.statusCode}');
        return [];
      }

      final html = resp.body;
      final document = parse(html);
      final rankings = <Map<String, String>>[];
      final rows = document.querySelectorAll('div[role="row"]');
      final gridContainer = document.querySelector(
        'div.ag-center-cols-container',
      );

      if (gridContainer != null) {
        final containerRows = gridContainer.querySelectorAll('div[role="row"]');
        for (final row in containerRows) {
          final parsed = _extractRow(row);
          if (parsed.isNotEmpty && parsed.length >= 2) {
            rankings.add(parsed);
          }
        }
      }

      if (rankings.isEmpty) {
        for (final row in rows) {
          final parsed = _extractRow(row);
          if (parsed.isNotEmpty && parsed.length >= 2) {
            rankings.add(parsed);
          }
        }
      }

      return rankings;
    } catch (e) {
      print('UEFA rankings HTTP parsing failed: $e');
      return [];
    }
  }

  Map<String, String> _extractRow(dynamic row) {
    final rowMap = <String, String>{};
    final cells = row.querySelectorAll('div[role="gridcell"]');

    for (final cell in cells) {
      final colId = cell.attributes['col-id'];
      if (colId == null) {
        continue;
      }

      final valueSpan = cell.querySelector('span.ag-cell-value');
      final value = valueSpan?.text.trim() ?? cell.text.trim();
      if (value.isNotEmpty) {
        rowMap[colId] = value;
      }
    }

    return rowMap;
  }

  String _formatRankingsToTxt(List<Map<String, String>> rankings) {
    final buffer = StringBuffer();
    buffer.writeln('=' * 80);
    buffer.writeln('UEFA CLUB RANKINGS');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Storage path: $_storagePath');
    buffer.writeln('=' * 80);
    buffer.writeln();

    if (rankings.isNotEmpty) {
      final headers = rankings.first.keys.toList();
      buffer.writeln(headers.join(' | '));
      buffer.writeln('-' * 80);
    }

    for (final row in rankings) {
      buffer.writeln(row.values.join(' | '));
    }

    buffer.writeln();
    buffer.writeln('=' * 80);
    buffer.writeln('Total: ${rankings.length} clubs');
    buffer.writeln('=' * 80);
    return buffer.toString();
  }

  Future<String> _saveToFile(String content) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(
      RegExp(r'[:.]'),
      '-',
    );
    final filename = 'rankings_$timestamp.txt';

    if (kIsWeb) {
      print('Web build prepared rankings file: $filename');
      return 'web: $filename';
    }

    throw UnsupportedError('File save not implemented for this platform');
  }

  static Future<String?> parseIfRelevant(
    String query, {
    UefaParser? parser,
  }) async {
    final relevance = _checkRelevance(query);
    if (relevance >= 1.0) {
      final instance = parser ?? UefaParser();
      return instance.parseAndSaveRankings();
    }
    return null;
  }

  static double _checkRelevance(String query) {
    final lowerQuery = query.toLowerCase();
    const triggers = [
      'ranking',
      'rankings',
      'рейтинг',
      'рейтинги',
      'uefa ranking',
      'uefa table',
      'таблица uefa',
      'клубный рейтинг',
      'рейтинг клубов',
      'coefficient',
      'коэффициент',
    ];

    for (final trigger in triggers) {
      if (lowerQuery.contains(trigger)) {
        return 2.0;
      }
    }

    const mediumTriggers = [
      'table',
      'таблица',
      'uefa',
      'уефа',
      'club',
      'клуб',
      'euro',
      'евро',
    ];
    for (final trigger in mediumTriggers) {
      if (lowerQuery.contains(trigger)) {
        return 1.0;
      }
    }

    return 0.0;
  }

  bool _looksLikeMatch(String text) {
    if (text.isEmpty) {
      return false;
    }
    final lower = text.toLowerCase();
    return lower.contains(' vs ') ||
        (lower.contains('-') && RegExp(r'\d').hasMatch(lower));
  }
}
