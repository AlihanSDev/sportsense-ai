import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Response from LangChain Search API
class LangChainSearchResponse {
  final String response;
  final String? reasoning;
  final String model;
  final bool usedSearch;

  LangChainSearchResponse({
    required this.response,
    this.reasoning,
    required this.model,
    required this.usedSearch,
  });
}

/// Service for communicating with the LangChain Search Python backend.
/// This backend uses HuggingFace's Inference API via LangChain's ChatOpenAI wrapper
/// and DuckDuckGo search as a tool.
class LangChainSearchService {
  final String baseUrl;
  final http.Client _client;

  LangChainSearchService({
    this.baseUrl = 'http://127.0.0.1:5002',
    http.Client? client,
  }) : _client = client ?? http.Client();

  /// Check if the LangChain Search API is available.
  Future<bool> isAvailable() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LangChain Search API недоступен: $e');
      return false;
    }
  }

  /// Send a chat message to the LangChain Search backend.
  ///
  /// If [useSearch] is true, the backend will perform a DuckDuckGo search
  /// and incorporate the results into the answer.
  /// Optionally provide [context] (RAG context from internal vector DB) which
  /// will be included as additional information.
  Future<LangChainSearchResponse?> chat(
    String message, {
    bool useSearch = false,
    String? context,
    int maxTokens = 512,
    double temperature = 0.7,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/chat'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'message': message,
              'use_search': useSearch,
              'context': context,
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return LangChainSearchResponse(
          response: data['response'] as String,
          reasoning: data['reasoning'] as String?,
          model: data['model'] as String,
          usedSearch: data['used_search'] as bool,
        );
      } else {
        debugPrint('❌ LangChain Search API error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ LangChain Search request error: $e');
      return null;
    }
  }

  void dispose() {
    _client.close();
  }
}
