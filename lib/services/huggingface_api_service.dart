import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Сервис для работы с HuggingFace Inference API (OpenAI-совместимый endpoint).
/// Использует router.huggingface.co/v1 для доступа к моделям Mistral, Qwen и др.
class HuggingFaceApiService {
  static const _baseUrl = 'https://router.huggingface.co/v1';
  final http.Client _client;

  String? _apiKey;
  String? _model;
  int _maxTokens = 1024;
  double _temperature = 0.7;

  HuggingFaceApiService({http.Client? client}) : _client = client ?? http.Client();

  /// Инициализация из .env файла.
  Future<bool> initialize() async {
    try {
      _apiKey = dotenv.env['HF_TOKEN']?.trim();
      _model = dotenv.env['HF_MODEL']?.trim() ?? 'mistralai/Mistral-7B-Instruct-v0.2';
      _maxTokens = int.tryParse(dotenv.env['HF_MAX_TOKENS'] ?? '1024') ?? 1024;
      _temperature = double.tryParse(dotenv.env['HF_TEMPERATURE'] ?? '0.7') ?? 0.7;

      if (_apiKey == null || _apiKey!.isEmpty) {
        print('[HF] ⚠️ HF_TOKEN не установлен в .env');
        return false;
      }
      print('[HF] ✅ Инициализирован: $_model');
      return true;
    } catch (e) {
      print('[HF] ❌ Ошибка инициализации: $e');
      return false;
    }
  }

  /// Проверка доступности API.
  Future<bool> isAvailable() async {
    if (_apiKey == null) return false;
    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (e) {
      print('[HF] ❌ API недоступен: $e');
      return false;
    }
  }

  /// Отправка запроса к чат-боту через HuggingFace.
  Future<HFChatResponse?> chat(String message, {
    int? maxTokens,
    double? temperature,
    String? context,
    bool useSearch = false,
    String? webContext,
  }) async {
    if (_apiKey == null) {
      print('[HF] ❌ API ключ не установлен');
      return null;
    }

    try {
      // Формируем системный промпт
      String systemPrompt;
      if (useSearch && webContext != null && webContext.isNotEmpty) {
        systemPrompt = (
          'Ты — Sportsense AI. Ниже приведена АКТУАЛЬНАЯ информация из интернета.\n\n'
          '=== НАЧАЛО ДАННЫХ ИЗ ИНТЕРНЕТА ===\n'
          '$webContext\n'
          '=== КОНЕЦ ДАННЫХ ИЗ ИНТЕРНЕТА ===\n\n'
          'ПРАВИЛА:\n'
          '1. ОТВЕЧАЙ НА РУССКОМ ЯЗЫКЕ.\n'
          '2. Используй ТОЛЬКО данные из блока выше.\n'
          '3. НЕ говори что не знаешь — информация УЖЕ предоставлена выше.\n'
          '4. НЕ упоминай дату своего обучения. Данные выше — самые свежие.\n'
          '5. Перескажи информацию своими словами, опираясь на источники.\n'
          '6. В конце ответа укажи источники в формате:\n'
          '   ---\n'
          '   Источники:\n'
          '   [1] Заголовок — URL'
        );
      } else if (context != null && context.isNotEmpty) {
        systemPrompt = (
          'Ты полезный ассистент Sportsense AI, специализирующийся на спортивной аналитике.\n'
          'Используй данные ниже для ответа:\n\n$context'
        );
      } else {
        systemPrompt = 'Ты полезный ассистент Sportsense AI, специализирующийся на спортивной аналитике и данных UEFA.';
      }

      print('[HF] 🤖 Запрос к $_model (search=$useSearch)...');

      final response = await _client.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'model': _model,
          'messages': [
            {'role': 'system', 'content': systemPrompt},
            {'role': 'user', 'content': message},
          ],
          'max_tokens': maxTokens ?? _maxTokens,
          'temperature': temperature ?? _temperature,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final choice = data['choices'] as List?;
        if (choice != null && choice.isNotEmpty) {
          final messageData = choice[0]['message'] as Map<String, dynamic>;
          final text = messageData['content'] as String;
          final usage = data['usage'] as Map<String, dynamic>?;
          print('[HF] ✅ Ответ получен (${usage?['total_tokens'] ?? '?'} tokens)');
          return HFChatResponse(
            response: text,
            model: _model ?? 'unknown',
            tokensUsed: usage?['total_tokens'] as int? ?? 0,
          );
        }
      } else {
        print('[HF] ❌ Ошибка ${response.statusCode}: ${response.body}');
      }
      return null;
    } catch (e) {
      print('[HF] ❌ Ошибка запроса: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}

/// Ответ от HuggingFace API.
class HFChatResponse {
  final String response;
  final String model;
  final int tokensUsed;

  HFChatResponse({
    required this.response,
    required this.model,
    required this.tokensUsed,
  });

  @override
  String toString() {
    return 'HFChatResponse(model: $model, tokens: $tokensUsed, response: "${response.substring(0, response.length.clamp(0, 50))}...")';
  }
}
