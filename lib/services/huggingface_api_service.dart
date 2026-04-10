import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Сервис для работы с HuggingFace Inference API.
/// При use_search=true — запрос идёт через Python сервер (/hf_chat)
/// который выполняет LangChain поиск и передаёт контекст модели.
/// При use_search=false — прямой запрос к HF Router.
class HuggingFaceApiService {
  static const _baseUrl = 'https://router.huggingface.co/v1';
  static const _localApiUrl = 'http://127.0.0.1:5000';
  final http.Client _client;

  String? _apiKey;
  String? _model;
  int _maxTokens = 1024;
  double _temperature = 0.7;

  HuggingFaceApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<bool> initialize() async {
    try {
      _apiKey = dotenv.env['HF_TOKEN']?.trim();
      _model = dotenv.env['HF_MODEL']?.trim() ?? 'Qwen/Qwen3.5-9B';
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
      if (useSearch) {
        return await _chatWithSearch(message, maxTokens, temperature);
      } else {
        return await _chatDirect(message, maxTokens, temperature, context);
      }
    } catch (e) {
      print('[HF] ❌ Ошибка запроса: $e');
      return null;
    }
  }

  /// Запрос через Python сервер с LangChain поиском
  Future<HFChatResponse?> _chatWithSearch(
    String message, int? maxTokens, double? temperature,
  ) async {
    print('[HF] 🌐 Запрос через LangChain search...');
    final response = await _client.post(
      Uri.parse('$_localApiUrl/hf_chat'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'message': message,
        'use_search': true,
        'max_tokens': maxTokens ?? _maxTokens,
        'temperature': temperature ?? _temperature,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      final result = HFChatResponse(
        response: data['response'] as String,
        model: data['model'] as String? ?? _model ?? 'unknown',
        tokensUsed: data['tokens_used'] as int? ?? 0,
      );
      print('[HF] ✅ Ответ через LangChain (${result.tokensUsed} tokens)');
      return result;
    } else {
      print('[HF] ❌ Ошибка ${response.statusCode}: ${response.body}');
      return null;
    }
  }

  /// Прямой запрос к HF Router
  Future<HFChatResponse?> _chatDirect(
    String message, int? maxTokens, double? temperature, String? context,
  ) async {
    final now = DateTime.now();
    final dateStr = '${now.day}.${now.month}.${now.year}';

    String systemPrompt;
    if (context != null && context.isNotEmpty) {
      systemPrompt = (
        'Ты — Sportsense AI. Сейчас $dateStr.\n'
        'Используй данные для ответа:\n\n$context'
      );
    } else {
      systemPrompt = (
        'Ты — Sportsense AI. Сейчас $dateStr.\n'
        'Специализация: спортивная аналитика, UEFA, футбол.\n'
        'Отвечай на русском языке.'
      );
    }

    print('[HF] 🤖 Прямой запрос к $_model...');

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
