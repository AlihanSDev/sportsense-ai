import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class HuggingFaceRouterService {
  final String baseUrl;
  final String apiKey;
  final http.Client _client;

  static const Map<String, String> availableModels = {
    'deepseek-ai/DeepSeek-R1-0528-Qwen3-8B:featherless-ai': 'DeepSeek R1',
    'mistralai/Mistral-7B-Instruct-v0.2:featherless-ai': 'Mistral 7B',
    'CohereLabs/c4ai-command-r7b-12-2024:cohere': 'Command R7B',
  };

  bool _showThinking = true;
  bool get showThinking => _showThinking;

  void toggleThinking() {
    _showThinking = !_showThinking;
    debugPrint('🤔 Thinking mode: $_showThinking');
  }

  static const String chartInstructions = '''
CHART RENDERING INSTRUCTIONS:
When user asks for charts, graphs, rankings comparisons, or visualizations - output a special JSON block like this:

<chart>
{"type":"bar","title":"Chart Title","labels":["A","B","C"],"values":[10,20,30],"colors":["#6366F1","#14B8A6","#F59E0B"]}
</chart>

Types: bar, line, pie, doughnut, horizontal_bar
Colors: #6366F1 (purple), #14B8A6 (teal), #F59E0B (amber), #EF4444 (red), #10B981 (green)
Max 8 data points. Always use quotes for all keys and values.''';

  static const String systemPrompt =
      '''You are SportSense AI - a brief football assistant. 

RULES:
1. Answer in 1-2 sentences MAXIMUM
2. NO explanations of your thinking
3. NO internal monologue or annotations
4. NO <environment_details> or XML tags
5. Start with the answer directly
6. If user asks about charts - output ONLY: <chart>{"type":"bar","title":"X","labels":["A","B"],"values":[1,2],"colors":["#6366F1","#14B8A6"]}</chart>
7. If you don't know - say "Не знаю" briefly''';

  String _selectedModel =
      'deepseek-ai/DeepSeek-R1-0528-Qwen3-8B:featherless-ai';

  HuggingFaceRouterService({
    required this.apiKey,
    this.baseUrl = 'https://router.huggingface.co/v1',
    http.Client? client,
  }) : _client = client ?? http.Client();

  String get selectedModel => _selectedModel;
  String get selectedModelName =>
      availableModels[_selectedModel] ?? _selectedModel;

  void setModel(String modelId) {
    if (availableModels.containsKey(modelId)) {
      _selectedModel = modelId;
      debugPrint('🤖 Model changed to: ${availableModels[modelId]}');
    }
  }

  List<MapEntry<String, String>> get modelsList =>
      availableModels.entries.toList();

  Future<HuggingFaceChatResponse?> chat(
    String message, {
    int maxTokens = 1024,
    double temperature = 0.7,
    String? context,
  }) async {
    // Build the user message with RAG context if available
    String userMessage = message;
    if (context != null && context.isNotEmpty) {
      userMessage =
          '''Context from database:
$context

User question: $message''';
    }

    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/chat/completions'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: json.encode({
              'model': _selectedModel,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                {'role': 'user', 'content': userMessage},
              ],
              'max_tokens': maxTokens,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 120));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;

        // Debug: print full response to see structure
        debugPrint('🔍 HF Response: ${response.body}');

        final choices = data['choices'] as List;
        if (choices.isNotEmpty) {
          final messageData = choices[0]['message'] as Map<String, dynamic>;
          String content = messageData['content'] as String;

          // Try different field names for reasoning
          String? reasoning =
              messageData['reasoning_content'] as String? ??
              messageData['reasoning'] as String? ??
              messageData['thought'] as String?;

          // Debug reasoning
          debugPrint(
            '🔍 Reasoning found: ${reasoning?.substring(0, reasoning.length.clamp(0, 100))}',
          );

          // Clean up DeepSeek reasoning tags
          content = _cleanResponse(content);

          // Parse chart data if present
          final chartData = _parseChartFromResponse(content);
          if (chartData != null) {
            // Remove chart block from text response
            content = content
                .replaceAll(RegExp(r'<chart>.*?</chart>', dotAll: true), '')
                .trim();
          }

          return HuggingFaceChatResponse(
            response: content,
            reasoning: reasoning,
            chartData: chartData,
            model: _selectedModel,
          );
        }
        return null;
      } else {
        debugPrint('❌ HF Router error: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ HF Router request error: $e');
      return null;
    }
  }

  String _cleanResponse(String text) {
    // Remove <environment_details> blocks
    final envRegex = RegExp(
      r'<environment_details>.*?</environment_details>',
      dotAll: true,
    );
    text = text.replaceAll(envRegex, '');

    // Remove <thinking> blocks
    final thinkingRegex = RegExp(r'<thinking>.*?</thinking>', dotAll: true);
    text = text.replaceAll(thinkingRegex, '');

    // Remove DeepSeek Qwen chat template artifacts (<|im_end|>, assistant/user tags)
    text = text.replaceAll(RegExp(r'<\|im_end\|>', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'<\|.*?\|>', dotAll: true), '');

    // Remove multi-line internal reasoning (DeepSeek patterns)
    final reasoningPattern = RegExp(
      r'^(Okay,|Looking at|I should|I will|Let me).*?(?=\n\n|$)',
      multiLine: true,
    );
    text = text.replaceAll(reasoningPattern, '');

    // Remove any remaining XML-like tags
    final xmlRegex = RegExp(r'<[^>]+>');
    text = text.replaceAll(xmlRegex, '');

    // Clean up extra whitespace
    text = text.trim();

    // If still has multiple paragraphs, keep only first paragraph
    final paragraphs = text.split('\n\n');
    if (paragraphs.length > 1) {
      text = paragraphs.first.trim();
    }

    // Also split by newlines and take first meaningful content
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      text = lines.first;
    }

    // Limit length
    if (text.length > 200) {
      text = text.substring(0, 197) + '...';
    }

    return text;
  }

  ChartData? _parseChartFromResponse(String text) {
    final chartRegex = RegExp(r'<chart>\s*(\{.*?\})\s*</chart>', dotAll: true);
    final match = chartRegex.firstMatch(text);
    if (match != null) {
      try {
        final jsonStr = match.group(1)!;
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return ChartData(
          type: map['type'] as String? ?? 'bar',
          title: map['title'] as String? ?? 'Chart',
          labels: (map['labels'] as List?)?.cast<String>() ?? [],
          values:
              (map['values'] as List?)
                  ?.map((e) => (e as num).toDouble())
                  .toList() ??
              [],
          colors: (map['colors'] as List?)?.cast<String>() ?? [],
        );
      } catch (e) {
        debugPrint('❌ Chart parse error: $e');
      }
    }
    return null;
  }

  void dispose() {
    _client.close();
  }
}

class HuggingFaceChatResponse {
  final String response;
  final String? reasoning;
  final ChartData? chartData;
  final String model;

  HuggingFaceChatResponse({
    required this.response,
    this.reasoning,
    this.chartData,
    required this.model,
  });
}

class ChartData {
  final String type;
  final String title;
  final List<String> labels;
  final List<double> values;
  final List<String> colors;

  ChartData({
    required this.type,
    required this.title,
    required this.labels,
    required this.values,
    required this.colors,
  });
}
