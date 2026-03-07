import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для взаимодействия с локальным Qwen API.
class QwenApiService {
  final String baseUrl;
  final http.Client _client;

  QwenApiService({
    this.baseUrl = 'http://127.0.0.1:5000',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Проверка доступности API.
  Future<bool> isAvailable() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/health'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['loaded'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Отправка запроса к чат-боту.
  Future<QwenChatResponse?> chat(String message, {
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': message,
          'max_tokens': maxTokens,
          'temperature': temperature,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return QwenChatResponse(
          response: data['response'] as String,
          model: data['model'] as String,
          tokensUsed: data['tokens_used'] as int,
        );
      } else {
        print('❌ Ошибка API: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ Ошибка запроса: $e');
      return null;
    }
  }

  /// Генерация текста (без системного промпта).
  Future<QwenGenerateResponse?> generate(String prompt, {
    int maxTokens = 512,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'prompt': prompt,
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return QwenGenerateResponse(
          text: data['text'] as String,
          tokens: data['tokens'] as int,
        );
      } else {
        return null;
      }
    } catch (e) {
      print('❌ Ошибка запроса: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Ответ от Qwen API на запрос чата.
class QwenChatResponse {
  final String response;
  final String model;
  final int tokensUsed;

  QwenChatResponse({
    required this.response,
    required this.model,
    required this.tokensUsed,
  });

  @override
  String toString() {
    return 'QwenChatResponse(model: $model, tokens: $tokensUsed, response: "${response.substring(0, response.length.clamp(0, 50))}...")';
  }
}

/// Ответ от Qwen API на запрос генерации.
class QwenGenerateResponse {
  final String text;
  final int tokens;

  QwenGenerateResponse({
    required this.text,
    required this.tokens,
  });
}
