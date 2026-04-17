import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для получения данных UEFA Rankings через Python API.
/// Использует Playwright для рендеринга JavaScript.
class UefaRankingsApiService {
  final String baseUrl;
  final http.Client _client;

  UefaRankingsApiService({
    this.baseUrl = 'http://127.0.0.1:5001',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Проверка доступности API.
  Future<bool> isAvailable() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Получение данных рейтинга (с кэшем).
  Future<UefaRankingsResponse?> getRankings() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/rankings'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return UefaRankingsResponse.fromJson(data);
      } else {
        print('❌ API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Request error: $e');
      return null;
    }
  }

  /// Получение свежих данных (без кэша).
  Future<UefaRankingsResponse?> getFreshRankings() async {
    try {
      print('🔄 Запрос свежих данных UEFA Rankings...');
      final response = await _client.get(
        Uri.parse('$baseUrl/rankings/fresh'),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = UefaRankingsResponse.fromJson(data);
        print('✅ Получено ${result.count} записей');
        return result;
      } else {
        print('❌ API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Request error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Ответ от UEFA Rankings API.
class UefaRankingsResponse {
  final String status;
  final String source;
  final List<Map<String, String>> data;
  final int count;
  final String timestamp;

  UefaRankingsResponse({
    required this.status,
    required this.source,
    required this.data,
    required this.count,
    required this.timestamp,
  });

  factory UefaRankingsResponse.fromJson(Map<String, dynamic> json) {
    final dataList = json['data'] as List? ?? [];
    return UefaRankingsResponse(
      status: json['status'] as String? ?? 'unknown',
      source: json['source'] as String? ?? 'unknown',
      data: dataList.map((e) => Map<String, String>.from(e)).toList(),
      count: json['count'] as int? ?? 0,
      timestamp: json['timestamp'] as String? ?? '',
    );
  }

  @override
  String toString() {
    return 'UefaRankingsResponse(source: $source, count: $count, timestamp: $timestamp)';
  }
}
