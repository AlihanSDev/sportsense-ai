import 'dart:convert';
import 'dart:math' show sqrt;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class HfEmbeddingService {
  static const int vectorSize = 768;

  final String baseUrl;
  final http.Client _client;

  HfEmbeddingService({String? baseUrl, http.Client? client})
    : baseUrl =
          baseUrl ??
          dotenv.env['HF_EMBEDDING_API_URL'] ??
          'http://127.0.0.1:5002',
      _client = client ?? http.Client();

  Future<bool> isAvailable() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<List<double>> embed(String text) async {
    final embeddings = await embedBatch([text]);
    return embeddings.first;
  }

  Future<List<List<double>>> embedBatch(List<String> texts) async {
    if (texts.isEmpty) {
      return const [];
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/embed'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({'texts': texts}),
          )
          .timeout(const Duration(seconds: 90));

      if (response.statusCode != 200) {
        print('Embedding API error: ${response.statusCode}');
        return texts.map(_fallbackEmbedding).toList();
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final rawEmbeddings = data['embeddings'] as List<dynamic>? ?? const [];

      if (rawEmbeddings.length != texts.length) {
        print('Embedding API returned unexpected batch size.');
        return texts.map(_fallbackEmbedding).toList();
      }

      return rawEmbeddings
          .map(
            (embedding) => _normalize(
              (embedding as List).map((v) => (v as num).toDouble()).toList(),
            ),
          )
          .toList();
    } catch (e) {
      print('Embedding API request failed: $e');
      return texts.map(_fallbackEmbedding).toList();
    }
  }

  Future<List<double>?> sentenceSimilarity({
    required String sourceSentence,
    required List<String> sentences,
  }) async {
    if (sentences.isEmpty) {
      return const [];
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/similarity'),
            headers: const {'Content-Type': 'application/json'},
            body: json.encode({
              'source_sentence': sourceSentence,
              'sentences': sentences,
            }),
          )
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        print('Similarity API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final scores = data['scores'] as List<dynamic>? ?? const [];
      return scores.map((score) => (score as num).toDouble()).toList();
    } catch (e) {
      print('Similarity API request failed: $e');
      return null;
    }
  }

  List<double> _fallbackEmbedding(String text) {
    if (text.isEmpty) {
      return List<double>.filled(vectorSize, 0);
    }

    final units = utf8.encode(text);
    final vector = List<double>.filled(vectorSize, 0);
    for (int i = 0; i < vector.length; i++) {
      final seed = units[i % units.length] ^ ((i + 1) * 31);
      vector[i] = ((seed % 1000) / 1000.0 - 0.5) * 2;
    }
    return _normalize(vector);
  }

  List<double> _normalize(List<double> vector) {
    double norm = 0;
    for (final value in vector) {
      norm += value * value;
    }

    if (norm == 0) {
      return vector;
    }

    final length = sqrt(norm);
    return vector.map((value) => value / length).toList();
  }

  void dispose() {
    _client.close();
  }
}
