/// Константы триггерных слов для активации модуля парсера UEFA.
/// Эти слова никогда не изменяются и хранятся в единой векторной базе.
class UefaTriggerConstants {
  /// Название коллекции в Qdrant (единая для всех триггеров)
  static const String collectionName = 'uefa_triggers';

  /// Размер вектора для эмбеддингов
  static const int vectorSize = 384;

  /// Порог схожести для поиска триггеров
  static const double similarityThreshold = 0.5;

  /// Путь к файлу с триггерами
  static const String triggerWordsAsset = 'assets/trigger_words.txt';
}
