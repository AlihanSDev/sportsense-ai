import 'dart:async';
import 'package:flutter/foundation.dart';
import 'trigger_words_service.dart';
import 'qdrant_client.dart';

/// Статус поиска данных UEFA
enum UefaSearchStatus {
  idle, // Нет активного поиска
  searching, // Идёт поиск информации (до ответа LLM)
  success, // Данные найдены, можно отправлять LLM
  error, // Ошибка при поиске
}

/// Менеджер для управления состоянием поиска данных UEFA.
/// Работает ДО отправки запроса к LLM (даже если API возвращает 401).
/// Перехватывает запрос пользователя, проверяет триггеры и показывает анимацию.
class UefaSearchManager extends ChangeNotifier {
  final TriggerWordsService _triggerService;
  
  UefaSearchStatus _status = UefaSearchStatus.idle;
  String _errorMessage = '';
  bool _isInitialized = false;
  
  // Таймер для автоматического сброса статуса
  Timer? _statusTimer;

  UefaSearchManager({TriggerWordsService? triggerService})
      : _triggerService = triggerService ?? TriggerWordsService();

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

  /// Инициализация сервиса (загрузка триггеров в Qdrant)
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      await _triggerService.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Ошибка инициализации UefaSearchManager: $e');
      // Продолжаем работу даже при ошибке инициализации
      _isInitialized = true;
    }
  }

  /// Проверка запроса ПЕРЕД отправкой к LLM.
  /// Возвращает true если найден триггер и нужно показать анимацию.
  /// Вызывается ДО любого обращения к HuggingFace API.
  Future<bool> interceptQuery(String query) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Специальная тестовая фраза BANANA-HEY (всегда срабатывает)
    if (query.trim().toUpperCase() == 'BANANA-HEY') {
      await _startSearch(isTest: true);
      return true;
    }

    // Проверяем наличие триггера в векторной базе
    final hasTrigger = await _triggerService.hasTrigger(query);
    
    if (hasTrigger) {
      // Запускаем процесс поиска ДО ответа LLM
      await _startSearch(isTest: false);
    }
    
    return hasTrigger;
  }

  /// Начало поиска (показываем анимацию)
  /// Вызывается сразу после обнаружения триггера, ДО LLM
  Future<void> _startSearch({bool isTest = false}) async {
    _status = UefaSearchStatus.searching;
    _errorMessage = '';
    notifyListeners();

    // Запуск поиска данных
    await _performSearch(isTest: isTest);
  }

  /// Выполнение поиска данных
  /// Для BANANA-HEY: 10 секунд ожидания, затем ошибка
  /// Для реальных триггеров: будущее обращение к парсеру
  Future<void> _performSearch({bool isTest = false}) async {
    try {
      if (isTest) {
        // Тестовый режим: 10 секунд ожидания, затем ошибка
        await Future.delayed(const Duration(seconds: 10));
        
        // Симуляция ошибки (нет подключения к сети)
        _status = UefaSearchStatus.error;
        _errorMessage = 'Нет подключения к интернету или сайт UEFA недоступен';
        notifyListeners();
        
        // Автоматический сброс через 5 секунд
        _statusTimer?.cancel();
        _statusTimer = Timer(const Duration(seconds: 5), () {
          _status = UefaSearchStatus.idle;
          notifyListeners();
        });
      } else {
        // Реальный режим: имитация поиска (2-3 секунды)
        await Future.delayed(const Duration(milliseconds: 2500));
        
        // Placeholder: всегда успешно (потом заменить на реальный парсер)
        _status = UefaSearchStatus.success;
        notifyListeners();
        
        // Автоматический сброс через 500мс после успеха
        _statusTimer?.cancel();
        _statusTimer = Timer(const Duration(milliseconds: 500), () {
          _status = UefaSearchStatus.idle;
          notifyListeners();
        });
      }
      
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
      await _startSearch(isTest: true);
    }
  }

  /// Сброс состояния (вызывается после отправки к LLM)
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
