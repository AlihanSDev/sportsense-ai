import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Клиент для работы с Qdrant векторной базой данных.
/// Используется для хранения и поиска триггерных слов.
class QdrantClient {
  final String url;
  final String? apiKey;
  final http.Client _client;

  QdrantClient({
    String? url,
    String? apiKey,
    http.Client? client,
  })  : url = url ?? dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333',
        apiKey = apiKey ?? dotenv.env['QDRANT_API_KEY'],
        _client = client ?? http.Client();

  /// Создание коллекции в Qdrant
  Future<bool> createCollection({
    required String collectionName,
    int vectorSize = 384,
    String distance = 'Cosine',
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({
          'vectors': {
            'size': vectorSize,
            'distance': distance,
          },
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Ошибка создания коллекции: $e');
      return false;
    }
  }

  /// Проверка существования коллекции
  Future<bool> collectionExists(String collectionName) async {
    try {
      final response = await _client.get(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Добавление векторов в коллекцию
  Future<bool> upsertPoints({
    required String collectionName,
    required List<Map<String, dynamic>> points,
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$url/collections/$collectionName/points'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({
          'points': points,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Ошибка добавления точек: $e');
      return false;
    }
  }

  /// Поиск похожих векторов
  Future<List<Map<String, dynamic>>> searchPoints({
    required String collectionName,
    required List<double> vector,
    int limit = 5,
    Map<String, dynamic>? filter,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$url/collections/$collectionName/points/search'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({
          'vector': vector,
          'limit': limit,
          if (filter != null) 'filter': filter,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return List<Map<String, dynamic>>.from(data['result'] ?? []);
      }
      return [];
    } catch (e) {
      print('Ошибка поиска: $e');
      return [];
    }
  }

  /// Удаление коллекции
  Future<bool> deleteCollection(String collectionName) async {
    try {
      final response = await _client.delete(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Удаление всех точек из коллекции
  Future<bool> clearCollection(String collectionName) async {
    try {
      final response = await _client.post(
        Uri.parse('$url/collections/$collectionName/points/delete'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({'filter': {}}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
