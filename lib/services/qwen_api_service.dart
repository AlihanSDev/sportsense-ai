import 'dart:convert';
import 'package:http/http.dart' as http;

/// Сервис для взаимодействия с локальным Qwen API.
class QwenApiService {
  String baseUrl;
  final http.Client _client;

  QwenApiService({
    this.baseUrl = 'http://10.0.2.2:5000',  // 10.0.2.2 for Android emulator, will fallback to 127.0.0.1
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Проверка доступности API.
  Future<bool> isAvailable() async {
    // Try both addresses: emulator (10.0.2.2) and localhost (127.0.0.1)
    final urls = ['http://10.0.2.2:5000/health', 'http://127.0.0.1:5000/health'];
    
    for (final url in urls) {
      try {
        print('🔍 Checking Qwen API availability at $url...');
        final response = await _client.get(
          Uri.parse(url),
        ).timeout(const Duration(seconds: 3));

        print('📡 Health response status: ${response.statusCode}');
        print('📄 Health response body: ${response.body}');

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final loaded = data['loaded'] == true;
          if (loaded) {
            print('✅ Qwen API available at $url');
            // Update baseUrl to the working one
            baseUrl = url.replaceAll('/health', '');
            return true;
          }
        }
      } catch (e) {
        print('❌ Qwen API not available at $url: $e');
      }
    }
    
    print('❌ Qwen API not available on any address');
    return false;
  }

  /// Отправка запроса к чат-боту с контекстом (RAG).
  Future<QwenChatResponse?> chat(String message, {
    int maxTokens = 1024,
    double temperature = 0.7,
    String? context, // Контекст из векторной базы для RAG
    bool useSearch = false, // Поиск в интернете через LangChain
  }) async {
    try {
      // Формируем промпт с контекстом для RAG
      final String prompt;
      if (context != null && context.isNotEmpty) {
        // RAG промпт: контекст + инструкция + вопрос
        prompt = '''$context

You are a helpful sports assistant specializing in UEFA football data.
Use the ranking data above to answer the user's question accurately.
If the data contains relevant information, reference it in your answer.
If the data doesn't contain what the user is asking, say so honestly.

User question: $message
''';
        print('📝 RAG Prompt length: ${prompt.length} chars');
      } else {
        prompt = message;
      }

      print('🤖 Sending request to Qwen API (search=$useSearch)...');

      final response = await _client.post(
        Uri.parse('$baseUrl/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'message': prompt,
          'max_tokens': maxTokens,
          'temperature': temperature,
          'use_search': useSearch,
        }),
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final sourcesList = <SearchSource>[];
        if (data['sources'] != null) {
          for (final s in data['sources'] as List) {
            sourcesList.add(SearchSource(
              title: s['title'] as String? ?? '',
              url: s['url'] as String? ?? '',
            ));
          }
        }
        final result = QwenChatResponse(
          response: data['response'] as String,
          model: data['model'] as String,
          tokensUsed: data['tokens_used'] as int,
          sources: sourcesList,
        );
        print('✅ Qwen response received (${result.tokensUsed} tokens, ${sourcesList.length} sources)');
        return result;
      } else {
        print('❌ API error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }
    } catch (e) {
      print('❌ Request error: $e');
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

/// Источник из поиска в интернете
class SearchSource {
  final String title;
  final String url;
  SearchSource({required this.title, required this.url});
}

/// Ответ от Qwen API на запрос чата.
class QwenChatResponse {
  final String response;
  final String model;
  final int tokensUsed;
  final List<SearchSource> sources;

  QwenChatResponse({
    required this.response,
    required this.model,
    required this.tokensUsed,
    this.sources = const [],
  });

  @override
  String toString() {
    return 'QwenChatResponse(model: $model, tokens: $tokensUsed, sources: ${sources.length}, response: "${response.substring(0, response.length.clamp(0, 50))}...")';
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
