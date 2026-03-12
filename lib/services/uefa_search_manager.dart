import 'dart:async';
import 'package:flutter/foundation.dart';

/// Статус поиска данных UEFA
enum UefaSearchStatus {
  idle, // Нет активного поиска
  searching, // Идёт поиск информации
  success, // Данные найдены
  error, // Ошибка при поиске
}

/// Менеджер для управления состоянием поиска данных UEFA.
/// Перехватывает запрос пользователя и показывает анимацию поиска.
class UefaSearchManager extends ChangeNotifier {
  UefaSearchStatus _status = UefaSearchStatus.idle;
  String _errorMessage = '';
  bool _isInitialized = false;

  // Таймер для автоматического сброса статуса
  Timer? _statusTimer;

  /// Текущий статус поиска
  UefaSearchStatus get status => _status;

  /// Сообщение об ошибке
  String get errorMessage => _errorMessage;

  /// Инициализирован ли сервис
  bool get isInitialized => _isInitialized;

  /// Идёт ли сейчас поиск
  bool get isSearching => _status == UefaSearchStatus.searching;

  /// Есть ли ошибка
  bool get hasError => _status == UefaSearchStatus.error;

  /// Инициализация сервиса
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    notifyListeners();
  }

  /// Проверка запроса ПЕРЕД отправкой к LLM.
  /// Возвращает true если найден триггер и нужно показать анимацию.
  Future<bool> interceptQuery(String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Проверка на триггерные слова UEFA
    final hasTrigger = _checkUefaTriggers(query);

    if (hasTrigger) {
      await _startSearch();
    }

    return hasTrigger;
  }

  /// Проверка на наличие триггерных слов UEFA
  bool _checkUefaTriggers(String query) {
    final lowerQuery = query.toLowerCase();
    
    final triggers = [
      // English
      'ranking', 'rankings', 'uefa ranking', 'uefa rankings',
      'club ranking', 'club rankings', 'team ranking', 'team rankings',
      'uefa table', 'uefa standings', 'uefa coefficient',
      'uefa club coefficient', 'uefa country coefficient',
      'uefa league', 'champions league', 'europa league',
      'conference league', 'uefa competitions',
      
      // Russian
      'рейтинг', 'рейтинги', 'рейтинг клубов', 'рейтинг uefa',
      'таблица uefa', 'коэффициент uefa', 'еврокубковый рейтинг',
      'лига чемпионов', 'лига европы', 'лига конференций',
      'uefa', 'уефа',
    ];

    return triggers.any((trigger) => lowerQuery.contains(trigger));
  }

  /// Начало поиска (показываем анимацию)
  Future<void> _startSearch() async {
    _status = UefaSearchStatus.searching;
    _errorMessage = '';
    notifyListeners();

    await _performSearch();
  }

  /// Выполнение поиска данных
  Future<void> _performSearch() async {
    try {
      // Имитация поиска (2-3 секунды)
      await Future.delayed(const Duration(milliseconds: 2500));

      // Успешный поиск
      _status = UefaSearchStatus.success;
      notifyListeners();

      // Автоматический сброс через 500мс после успеха
      _statusTimer?.cancel();
      _statusTimer = Timer(const Duration(milliseconds: 500), () {
        _status = UefaSearchStatus.idle;
        notifyListeners();
      });

    } catch (e) {
      _status = UefaSearchStatus.error;
      _errorMessage = 'Ошибка при поиске данных: ${e.toString()}';
      notifyListeners();
    }
  }

  /// Симуляция ошибки (для тестирования)
  Future<void> simulateError() async {
    _status = UefaSearchStatus.searching;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 2000));

    _status = UefaSearchStatus.error;
    _errorMessage = 'Нет подключения к интернету или сайт UEFA недоступен';
    notifyListeners();
  }

  /// Повтор попытки после ошибки
  Future<void> retry() async {
    if (_status == UefaSearchStatus.error) {
      await _startSearch();
    }
  }

  /// Сброс состояния
  void reset() {
    _statusTimer?.cancel();
    _status = UefaSearchStatus.idle;
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }
}
