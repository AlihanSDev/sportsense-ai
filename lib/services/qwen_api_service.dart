import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service for interacting with Hugging Face Router API.
class QwenApiService {
  final String baseUrl;
  final String apiKey;
  final String model;
  final http.Client _client;

  QwenApiService({
    String? baseUrl,
    String? apiKey,
    String? model,
    http.Client? client,
  }) : baseUrl =
           baseUrl ??
           dotenv.env['HF_BASE_URL'] ??
           'https://router.huggingface.co/v1',
       apiKey = apiKey ?? dotenv.env['HF_TOKEN'] ?? '',
       model =
           model ??
           dotenv.env['HF_CHAT_MODEL'] ??
           'meta-llama/Llama-3.1-8B-Instruct:sambanova',
       _client = client ?? http.Client();

  Future<bool> isAvailable() async {
    if (apiKey.isEmpty) {
      print('HF_TOKEN is empty. Hugging Face API is disabled.');
      return false;
    }

    try {
      final response = await _client
          .get(
            Uri.parse('https://huggingface.co/api/whoami-v2'),
            headers: {'Authorization': 'Bearer $apiKey'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('HF availability check failed: $e');
      return false;
    }
  }

  Future<QwenChatResponse?> chat(
    String message, {
    int maxTokens = 1024,
    double temperature = 0.7,
    String? context,
    String? temporalContext,
  }) async {
    if (apiKey.isEmpty) {
      print('HF_TOKEN is empty. Skipping chat request.');
      return null;
    }

    try {
      final mergedContext = [
        if (context != null && context.isNotEmpty) context,
        if (temporalContext != null && temporalContext.isNotEmpty)
          temporalContext,
      ].join('\n\n');

      final systemPrompt = mergedContext.isNotEmpty
          ? '''You are a helpful sports assistant specializing in UEFA football data.
Use the ranking data below to answer the user's question accurately.
If the data contains relevant information, reference it in your answer.
If the data doesn't contain what the user is asking, say so honestly.
Treat exact association matches and explicit ranking numbers as higher-priority than generic semantic matches.
Do not invent standings that are not present in the retrieved context.

Context:
$mergedContext'''
          : 'You are a helpful sports assistant specializing in UEFA football data.';

      print('Sending request to Hugging Face API...');

      final response = await _client
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: json.encode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': message},
              ],
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
        print('HF API error: ${response.statusCode}');
        print('Response body: ${response.body}');
        return null;
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) {
        print('HF API returned no choices');
        return null;
      }

      final messageData =
          choices.first['message'] as Map<String, dynamic>? ?? const {};
      final usage = data['usage'] as Map<String, dynamic>? ?? const {};

      final result = QwenChatResponse(
        response: (messageData['content'] as String?)?.trim() ?? '',
        model: data['model'] as String? ?? model,
        tokensUsed: (usage['total_tokens'] as num?)?.toInt() ?? 0,
      );

      print('HF response received (${result.tokensUsed} tokens)');
      return result;
    } catch (e) {
      print('HF request error: $e');
      return null;
    }
  }

  Future<QwenGenerateResponse?> generate(
    String prompt, {
    int maxTokens = 512,
  }) async {
    final chatResponse = await chat(
      prompt,
      maxTokens: maxTokens,
      temperature: 0.7,
    );

    if (chatResponse == null) {
      return null;
    }

    return QwenGenerateResponse(
      text: chatResponse.response,
      tokens: chatResponse.tokensUsed,
    );
  }

  void dispose() {
    _client.close();
  }
}

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
    final previewLength = response.length < 50 ? response.length : 50;
    final preview = response.substring(0, previewLength);
    return 'QwenChatResponse(model: $model, tokens: $tokensUsed, response: "$preview...")';
  }
}

class QwenGenerateResponse {
  final String text;
  final int tokens;

  QwenGenerateResponse({required this.text, required this.tokens});
}
