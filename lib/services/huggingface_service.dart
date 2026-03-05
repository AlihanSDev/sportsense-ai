import 'dart:convert';
import 'package:http/http.dart' as http;

class Message {
  final String role;
  final String content;

  Message({required this.role, required this.content});

  Map<String, String> toJson() => {'role': role, 'content': content};
}

class HuggingFaceService {
  static const String baseUrl = 'https://router.huggingface.co/v1';
  static const String model = 'meta-llama/Llama-3.1-8B-Instruct:novita';
  static const String systemPrompt = '''Вы — профессиональный спортивный аналитик и прогнозист с глубокими знаниями в области спорта.

ВАШИ КОМПЕТЕНЦИИ:
1. **Предстоящие матчи**: Знаете расписание будущих игр, турниров и соревнований
2. **Прошедшие матчи**: Анализируете результаты завершённых игр, ключевые моменты и поворотные точки
3. **Статистика команд и игроков**: 
   - Форма команды (последние 5-10 игр)
   - Домашние/выездные результаты
   - Забитые/пропущенные голы
   - Владение мячом, удары, передачи
   - Индивидуальная статистика игроков
4. **Прогнозирование**:
   - Вероятность победы каждой из сторон (%)
   - Возможный счёт
   - Тоталы (больше/меньше)
   - Индивидуальные достижения игроков
5. **Факторы влияния**:
   - Травмы и дисквалификации ключевых игроков
   - Погодные условия
   - Мотивация команд
   - Исторические противостояния (H2H)

СТИЛЬ ОТВЕТА:
- Структурированный анализ с цифрами и фактами
- Чёткие прогнозы с указанием вероятностей
- Объяснение логики прогноза
- Предупреждение о рисках и неопределённостях
- Профессиональный, но доступный язык

ВАЖНО:
- Если точных данных нет — честно сообщайте об этом
- Прогнозы — это вероятности, а не гарантии
- Используйте актуальную статистику''';

  final String _apiKey;

  HuggingFaceService({required String apiKey}) : _apiKey = apiKey;

  /// Отправляет запрос к API с одним сообщением
  Future<String> chat(String userMessage) async {
    final messages = [
      Message(role: 'system', content: systemPrompt),
      Message(role: 'user', content: userMessage),
    ];
    final response = await _sendRequest(messages);
    return response;
  }

  /// Отправляет запрос к API с историей диалога
  Future<String> chatWithHistory(List<Message> messages) async {
    final allMessages = [
      Message(role: 'system', content: systemPrompt),
      ...messages,
    ];
    return await _sendRequest(allMessages);
  }

  Future<String> _sendRequest(List<Message> messages) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages.map((m) => m.toJson()).toList(),
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
