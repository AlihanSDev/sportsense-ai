import 'package:flutter/material.dart';
import '../services/uefa_search_manager.dart';
import '../widgets/uefa_search_indicator.dart';

/// Helper для интеграции UEFA Search в чат.
/// 
/// Пример использования в вашем chat экране:
/// 
/// ```dart
/// class ChatScreen extends StatefulWidget {
///   @override
///   State<ChatScreen> createState() => _ChatScreenState();
/// }
/// 
/// class _ChatScreenState extends State<ChatScreen> {
///   final UefaSearchManager _uefaSearch = UefaSearchManager();
///   final TextEditingController _controller = TextEditingController();
///   bool _showUefaIndicator = false;
/// 
///   @override
///   void initState() {
///     super.initState();
///     _uefaSearch.initialize();
///     _uefaSearch.addListener(_onUefaSearchChanged);
///   }
/// 
///   void _onUefaSearchChanged() {
///     setState(() {
///       _showUefaIndicator = _uefaSearch.isSearching;
///     });
///   }
/// 
///   Future<void> _sendMessage() async {
///     final query = _controller.text.trim();
///     if (query.isEmpty) return;
/// 
///     // ПЕРЕХВАТ ЗАПРОСА ДО LLM
///     final hasTrigger = await _uefaSearch.interceptQuery(query);
/// 
///     if (hasTrigger) {
///       // Показываем анимацию "Поиск актуальной информации..."
///       // Ждём пока UefaSearchManager завершит поиск
///       // Потом отправляем запрос к LLM
///       
///       await _waitForSearchComplete();
///       
///       // Теперь отправляем к LLM (даже если API возвращает 401)
///       await _sendToLlm(query);
///       
///       _uefaSearch.reset();
///     } else {
///       // Нет триггера - сразу к LLM
///       await _sendToLlm(query);
///     }
///   }
/// 
///   Future<void> _waitForSearchComplete() async {
///     // Ждём пока статус не станет success или error
///     while (_uefaSearch.isSearching) {
///       await Future.delayed(const Duration(milliseconds: 100));
///     }
///   }
/// 
///   Future<void> _sendToLlm(String query) async {
///     // Ваш существующий код для отправки к HuggingFace API
///     // Даже если вернётся 401 - анимация уже отработала
///   }
/// 
///   @override
///   Widget build(BuildContext context) {
///     return Column(
///       children: [
///         // Список сообщений
///         Expanded(child: _buildMessages()),
///         
///         // Индикатор UEFA Search
///         if (_showUefaIndicator)
///           const UefaSearchIndicator(),
///         
///         // Поле ввода
///         _buildInput(),
///       ],
///     );
///   }
/// }
/// ```

/// Виджет-обёртка для отображения индикатора UEFA Search
class UefaSearchWrapper extends StatelessWidget {
  final UefaSearchManager searchManager;
  final Widget child;
  
  const UefaSearchWrapper({
    super.key,
    required this.searchManager,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: searchManager,
      builder: (context, _) {
        return Column(
          children: [
            child,
            
            // Индикатор поиска
            if (searchManager.isSearching)
              const UefaSearchIndicator(),
            
            // Индикатор ошибки
            if (searchManager.hasError)
              UefaErrorIndicator(
                message: searchManager.errorMessage,
                onRetry: () => searchManager.retry(),
              ),
          ],
        );
      },
    );
  }
}

/// Extension для удобной проверки триггеров
extension UefaSearchExtension on String {
  /// Проверка строки на наличие UEFA триггеров
  Future<bool> hasUefaTrigger({TriggerWordsService? service}) async {
    final triggerService = service ?? TriggerWordsService();
    await triggerService.initialize();
    return triggerService.hasTrigger(this);
  }
}
