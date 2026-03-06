/// Константы триггерных слов для активации модуля парсера UEFA.
/// Эти слова никогда не изменяются и хранятся в единой векторной базе.
class UefaTriggerConstants {
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

  /// Все триггеры вместе (неизменяемый список)
  static List<String> get all => List.unmodifiable([...english, ...russian]);

  /// Название коллекции в Qdrant (единая для всех триггеров)
  static const String collectionName = 'uefa_triggers';

  /// Размер вектора для эмбеддингов
  static const int vectorSize = 384;

  /// Порог схожести для поиска триггеров
  static const double similarityThreshold = 0.7;
}
