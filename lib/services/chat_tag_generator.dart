import 'dart:convert';
import 'package:http/http.dart' as http;

/// Генератор тегов и названий для чатов на основе вопросов пользователя.
/// 
/// Использует локальный LLM API для определения темы вопроса
/// и создания краткого описания чата.
class ChatTagGenerator {
  final String apiBaseUrl;
  
  // Кэш для часто используемых тем
  static final Map<String, String> _topicCache = {};
  
  // Ключевые слова для определения тем (локальный fallback)
  static final Map<String, List<String>> _topicKeywords = {
    'футбол': ['футбол', 'football', 'гол', 'матч', 'лига', 'чемпионат', 'команда', 'игрок', 'мяч', 'поле', 'ворота', 'арбитр', 'penalty', 'goal'],
    'баскетбол': ['баскетбол', 'basketball', 'NBA', 'корзина', 'трехочковой', 'драфт'],
    'хоккей': ['хоккей', 'hockey', 'NHL', 'шайба', 'клюшка', 'каток'],
    'теннис': ['теннис', 'tennis', 'ракетка', 'сет', 'гейм', 'Wimbledon'],
    'бокс': ['бокс', 'boxing', 'нокаут', 'раунд', 'пояс', 'боец'],
    'формула 1': ['формула', 'F1', 'гонки', '赛车', 'болид', 'трасса', 'pit stop'],
    'UEFA': ['UEFA', 'уефа', 'рейтинг', 'ранкинг', 'клуб', 'еврокубки'],
    'тренер': ['тренер', 'coach', 'тренировка', 'тактика', 'стратегия'],
    'трансфер': ['трансфер', 'transfer', 'контракт', 'подписание', 'уход'],
    'здоровье': ['здоровье', 'здоров', 'травма', 'лечение', 'врач', 'медицина', 'боль', 'симптом', 'диагноз', 'лекарство', 'hospital', 'doctor'],
    'технологии': ['технологии', 'компьютер', 'программирование', 'код', 'software', 'hardware', 'AI', 'нейросеть', 'алгоритм'],
    'еда': ['еда', 'рецепт', 'готовить', 'кухня', 'блюдо', 'ингредиент', 'cook', 'food', 'recipe'],
    'путешествия': ['путешествие', 'поездка', 'отпуск', 'туризм', 'билет', 'отель', 'travel', 'trip'],
    'музыка': ['музыка', 'песня', 'альбом', 'концерт', 'исполнитель', 'music', 'song'],
    'кино': ['кино', 'фильм', 'movie', 'актер', 'режиссер', 'сериал'],
    'наука': ['наука', 'исследование', 'эксперимент', 'теория', 'science', 'physics', 'chemistry'],
    'история': ['история', 'исторический', 'эпоха', 'война', 'history', 'century'],
    'экономика': ['экономика', 'финансы', 'деньги', 'рынок', 'акции', 'economy', 'finance'],
    'политика': ['политика', 'выборы', 'правительство', 'партия', 'politics', 'election'],
    'образование': ['образование', 'учеба', 'университет', 'курс', 'education', 'university', 'study'],
  };

  ChatTagGenerator({required this.apiBaseUrl});

  /// Генерирует название чата на основе первого вопроса пользователя.
  /// 
  /// [userMessage] - сообщение пользователя
  /// Возвращает краткое описание чата
  Future<String> generateChatTitle(String userMessage) async {
    // Проверяем кэш
    final cacheKey = userMessage.toLowerCase().substring(0, 
        userMessage.length > 50 ? 50 : userMessage.length);
    if (_topicCache.containsKey(cacheKey)) {
      return _topicCache[cacheKey]!;
    }

    // Пытаемся использовать LLM для генерации
    try {
      final llmTitle = await _generateWithLLM(userMessage);
      if (llmTitle != null && llmTitle.isNotEmpty) {
        _topicCache[cacheKey] = llmTitle;
        return llmTitle;
      }
    } catch (e) {
      print('⚠️ LLM недоступен для генерации тега: $e');
    }

    // Fallback: локальный анализ ключевых слов
    final localTitle = _generateLocally(userMessage);
    _topicCache[cacheKey] = localTitle;
    return localTitle;
  }

  /// Генерация названия с помощью LLM API
  Future<String?> _generateWithLLM(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'prompt': '''Ты - помощник для создания кратких названий чатов.
Проанализируй вопрос пользователя и создай краткое название чата (максимум 5-6 слов).
Название должно отражать тему вопроса.

Формат ответа: только название, без кавычек и дополнительного текста.

Примеры:
- Пользователь: "Какие команды играют в Лиге Чемпионов?" → "Вопрос про Лигу Чемпионов"
- Пользователь: "Расскажи про здоровье" → "Вопрос про здоровье"
- Пользователь: "Как работает нейросеть?" → "Вопрос про нейросети"

Вопрос пользователя: "$userMessage"

Название чата:''',
          'max_tokens': 50,
          'temperature': 0.3,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String title = data['text']?.toString().trim() ?? '';
        
        // Очищаем ответ
        title = title.replaceAll(RegExp(r'^["\s]+|["\s]+$'), '');
        if (title.length > 50) {
          title = title.substring(0, 47) + '...';
        }
        
        if (title.isNotEmpty) {
          return '💬 $title';
        }
      }
    } catch (e) {
      print('Ошибка LLM генерации: $e');
    }
    return null;
  }

  /// Локальная генерация названия на основе ключевых слов
  String _generateLocally(String userMessage) {
    final messageLower = userMessage.toLowerCase();
    
    // Ищем совпадения с ключевыми словами
    for (final entry in _topicKeywords.entries) {
      final topic = entry.key;
      final keywords = entry.value;
      
      for (final keyword in keywords) {
        if (messageLower.contains(keyword.toLowerCase())) {
          return '💬 Вопрос про $topic';
        }
      }
    }

    // Если тема не найдена, используем первые слова
    final words = userMessage.split(' ').take(4).join(' ');
    if (words.length > 30) {
      return '💬 ${words.substring(0, 27)}...';
    }
    return '💬 $words';
  }

  /// Генерирует краткую сводку сообщений чата для векторизации
  String generateChatSummary(List<Map<String, dynamic>> messages) {
    if (messages.isEmpty) return '';
    
    final buffer = StringBuffer();
    int messageCount = 0;
    
    for (final msg in messages) {
      if (messageCount >= 10) break; // Берем только первые 10 сообщений
      
      final isUser = msg['is_user'] == true || msg['is_user'] == 1;
      final text = msg['text']?.toString() ?? '';
      
      if (text.isNotEmpty) {
        buffer.writeln('${isUser ? "Пользователь" : "Бот"}: $text');
        messageCount++;
      }
    }
    
    return buffer.toString();
  }

  /// Очищает кэш
  void clearCache() {
    _topicCache.clear();
  }
}