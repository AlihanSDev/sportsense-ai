/// Триггерные слова для активации модуля парсера UEFA.
/// 
/// Если пользовательский запрос содержит одно из этих слов (в любом регистре),
/// будет запущен модуль парсера для получения данных с uefa.com.
class UefaTriggerWords {
  /// Триггеры на английском языке
  static const List<String> english = [
    'ranking',
    'rankings',
    'uefa ranking',
    'uefa rankings',
    'club ranking',
    'club rankings',
    'team ranking',
    'team rankings',
    'uefa table',
    'uefa standings',
    'coefficient ranking',
    'uefa coefficient',
  ];

  /// Триггеры на русском языке
  static const List<String> russian = [
    'рейтинг',
    'рейтинги',
    'рейтинг клубов',
    'рейтинг uefa',
    'таблица uefa',
    'коэффициент uefa',
    'еврокубковый рейтинг',
    'позиция в рейтинге',
  ];

  /// Все триггеры вместе
  static List<String> get all => [...english, ...russian];

  /// Проверка наличия триггера в запросе пользователя
  static bool hasTrigger(String query) {
    final lowerQuery = query.toLowerCase();
    return all.any((trigger) => lowerQuery.contains(trigger));
  }
}
