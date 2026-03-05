import 'dart:convert';
import 'package:http/http.dart' as http;

class QdrantClient {
  final String baseUrl;
  final String? apiKey;

  QdrantClient({
    required this.baseUrl,
    this.apiKey,
  });

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
      };

  /// Создание коллекции
  Future<bool> createCollection({
    required String collectionName,
    int vectorSize = 1536,
    String distance = 'Cosine',
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/collections/$collectionName'),
        headers: _headers,
        body: jsonEncode({
          'vectors': {
            'size': vectorSize,
            'distance': distance,
          },
        }),
      );

      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    } catch (e) {
      throw Exception('Ошибка создания коллекции: $e');
    }
  }

  /// Проверка существования коллекции
  Future<bool> collectionExists(String collectionName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collections/$collectionName'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      return data['result']?['exists'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Добавление точки (вектора)
  Future<bool> upsertPoint({
    required String collectionName,
    required String id,
    required List<double> vector,
    Map<String, dynamic>? payload,
  }) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/collections/$collectionName/points'),
        headers: _headers,
        body: jsonEncode({
          'points': [
            {
              'id': id,
              'vector': vector,
              'payload': payload,
            },
          ],
        }),
      );

      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    } catch (e) {
      throw Exception('Ошибка добавления точки: $e');
    }
  }

  /// Поиск похожих векторов
  Future<List<Map<String, dynamic>>> search({
    required String collectionName,
    required List<double> vector,
    int limit = 5,
    Map<String, dynamic>? filter,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collections/$collectionName/points/search'),
        headers: _headers,
        body: jsonEncode({
          'vector': vector,
          'limit': limit,
          'filter': filter,
          'with_payload': true,
          'with_vector': false,
        }),
      );

      final data = jsonDecode(response.body);
      final results = data['result'] as List;
      return results.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      throw Exception('Ошибка поиска: $e');
    }
  }

  /// Удаление точки
  Future<bool> deletePoint({
    required String collectionName,
    required List<String> ids,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/collections/$collectionName/points/delete'),
        headers: _headers,
        body: jsonEncode({
          'points': ids,
        }),
      );

      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    } catch (e) {
      throw Exception('Ошибка удаления точки: $e');
    }
  }

  /// Получение информации о коллекции
  Future<Map<String, dynamic>?> getCollectionInfo(String collectionName) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/collections/$collectionName'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      return data['result'];
    } catch (e) {
      return null;
    }
  }

  /// Удаление коллекции
  Future<bool> deleteCollection(String collectionName) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/collections/$collectionName'),
        headers: _headers,
      );

      final data = jsonDecode(response.body);
      return data['status'] == 'ok';
    } catch (e) {
      throw Exception('Ошибка удаления коллекции: $e');
    }
  }
}
