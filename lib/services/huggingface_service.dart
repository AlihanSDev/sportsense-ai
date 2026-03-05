import 'dart:convert';
import 'package:http/http.dart' as http;

class HuggingFaceService {
  static const String _baseUrl = 'https://router.huggingface.co/v1';
  static const String _model = 'Qwen/Qwen2-1.5B-Instruct:featherless-ai';
  
  final String _apiKey;

  HuggingFaceService({required String apiKey}) : _apiKey = apiKey;

  Future<String> chat(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'user',
              'content': userMessage,
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Ошибка API: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Ошибка подключения: $e');
    }
  }
}
