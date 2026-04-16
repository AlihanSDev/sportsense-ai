import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Сервис для работы с HuggingFace Inference API (Router).
/// Все запросы идут напрямую к HF Router, без Python сервера.
class HuggingFaceApiService {
  static const _baseUrl = 'https://router.huggingface.co/v1';
  final http.Client _client;

  String? _apiKey;
  String? _model;
  int _maxTokens = 512; // Ограничено для экономии токенов
  double _temperature = 0.7;

  HuggingFaceApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<bool> initialize() async {
    try {
      _apiKey = dotenv.env['HF_TOKEN']?.trim();
      _model = dotenv.env['HF_MODEL']?.trim() ?? 'Qwen/Qwen3.5-9B';
      _maxTokens = int.tryParse(dotenv.env['HF_MAX_TOKENS'] ?? '512') ?? 512;
      _temperature = double.tryParse(dotenv.env['HF_TEMPERATURE'] ?? '0.7') ?? 0.7;

      if (_apiKey == null || _apiKey!.isEmpty) {
        print('[HF] ⚠️ HF_TOKEN не установлен в .env');
        return false;
      }
      print('[HF] ✅ Инициализирован: $_model (max $_maxTokens tokens)');
      return true;
    } catch (e) {
      print('[HF] ❌ Ошибка инициализации: $e');
      return false;
    }
  }

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

  /// Основной метод чата. Все запросы идут напрямую к HF Router.
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
      final now = DateTime.now();
      final dateStr = '${now.day}.${now.month}.${now.year}';

      String systemPrompt;
      if (webContext != null && webContext.isNotEmpty) {
        systemPrompt = (
          'You are Sportsense AI, a smart sports assistant. Current date: $dateStr.\n\n'
          'Here is ACTUAL information from the internet:\n\n'
          '=== BEGIN INTERNET DATA ===\n'
          '$webContext\n'
          '=== END INTERNET DATA ===\n\n'
          'RULES:\n'
          '1. Respond in RUSSIAN language.\n'
          '2. Use ONLY the data from the block above.\n'
          '3. Do NOT say you don\'t know — the information is ALREADY provided.\n'
          '4. Current date is $dateStr. Do NOT mention your training cutoff.\n'
          '5. At the end list sources: ---\nSources:\n[1] Title — URL'
        );
      } else if (context != null && context.isNotEmpty) {
        systemPrompt = (
          'You are Sportsense AI. Current date: $dateStr.\n'
          'Use this data to answer:\n\n$context'
        );
      } else {
        systemPrompt = (
          'You are Sportsense AI, a smart sports assistant. Current date: $dateStr.\n'
          'You specialize in sports analytics, UEFA data, and football.\n'
          'Respond in Russian. Be helpful, accurate, and concise.\n'
          'If you don\'t know something, say so honestly.'
        );
      }

      // Ограничиваем токены
      final tokens = maxTokens != null ? maxTokens.clamp(64, 512) : _maxTokens;

      print('[HF] 🤖 Запрос к $_model (max $tokens tokens, search=$useSearch)...');

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
          'max_tokens': tokens,
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
          print('[HF] ✅ Ответ (${usage?['total_tokens'] ?? '?'} tokens)');
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

class HFChatResponse {
  final String response;
  final String model;
  final int tokensUsed;
  HFChatResponse({required this.response, required this.model, required this.tokensUsed});
}

