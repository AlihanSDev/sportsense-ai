import 'dart:math';
import 'dart:collection';

/// Легковесный TF-IDF векторизатор для локальной работы.
/// Не требует внешних зависимостей и работает офлайн.
class LocalEmbedding {
  final Map<String, int> _vocabulary = {};
  final Map<int, Map<String, double>> _tfIdfVectors = {};
  final List<String> _documents = [];
  bool _isTrained = false;

  /// Токенизация текста
  List<String> _tokenize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\sа-яё-]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty && t.length > 1)
        .toList();
  }

  /// Обучение на документах
  void train(List<String> documents) {
    _documents.clear();
    _vocabulary.clear();
    _tfIdfVectors.clear();
    
    // Построение словаря
    for (var doc in documents) {
      _documents.add(doc);
      final tokens = _tokenize(doc);
      for (var token in tokens) {
        _vocabulary.putIfAbsent(token, () => _vocabulary.length);
      }
    }

    // Вычисление IDF
    final idf = <String, double>{};
    for (var entry in _vocabulary.entries) {
      final word = entry.key;
      final docCount = _documents.where((doc) {
        final tokens = _tokenize(doc);
        return tokens.contains(word);
      }).length;
      idf[word] = log(_documents.length / (docCount + 1)) + 1;
    }

    // Вычисление TF-IDF векторов
    for (var i = 0; i < _documents.length; i++) {
      final doc = _documents[i];
      final tokens = _tokenize(doc);
      final tf = <String, double>{};
      
      // Частота термина
      for (var token in tokens) {
        tf[token] = (tf[token] ?? 0) + 1;
      }
      
      // Нормализация TF
      final maxFreq = tf.values.fold<double>(0, (a, b) => max(a, b));
      if (maxFreq > 0) {
        for (var key in tf.keys) {
          tf[key] = tf[key]! / maxFreq;
        }
      }

      // TF-IDF вектор
      final vector = <String, double>{};
      for (var entry in tf.entries) {
        vector[entry.key] = entry.value * (idf[entry.key] ?? 1);
      }
      
      _tfIdfVectors[i] = vector;
    }

    _isTrained = true;
  }

  /// Векторизация запроса
  List<double> transform(String query) {
    if (!_isTrained || _vocabulary.isEmpty) {
      return List.filled(384, 0.0);
    }

    final tokens = _tokenize(query);
    final vector = List<double>.filled(_vocabulary.length, 0.0);

    for (var token in tokens) {
      final index = _vocabulary[token];
      if (index != null) {
        vector[index] = 1.0;
      }
    }

    // Нормализация
    final magnitude = sqrt(vector.fold<double>(
      0.0,
      (sum, val) => sum + val * val,
    ));
    
    if (magnitude > 0) {
      for (var i = 0; i < vector.length; i++) {
        vector[i] /= magnitude;
      }
    }

    return vector;
  }

  /// Косинусное сходство
  double cosineSimilarity(List<double> a, List<double> b) {
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    
    for (var i = 0; i < a.length && i < b.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    
    if (normA == 0 || normB == 0) return 0.0;
    return dot / (sqrt(normA) * sqrt(normB));
  }

  /// Поиск наиболее похожих документов
  List<Map<String, dynamic>> searchSimilar(
    String query, {
    int limit = 5,
  }) {
    if (!_isTrained) return [];

    final queryVector = transform(query);
    final results = <Map<String, dynamic>>[];

    for (var i = 0; i < _documents.length; i++) {
      final docVector = _vectorToList(_tfIdfVectors[i] ?? {});
      final similarity = cosineSimilarity(queryVector, docVector);
      
      results.add({
        'index': i,
        'text': _documents[i],
        'score': similarity,
      });
    }

    // Сортировка по убыванию схожести
    results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
    
    return results.take(limit).toList();
  }

  List<double> _vectorToList(Map<String, double> vector) {
    final result = List<double>.filled(_vocabulary.length, 0.0);
    for (var entry in vector.entries) {
      final index = _vocabulary[entry.key];
      if (index != null) {
        result[index] = entry.value;
      }
    }
    return result;
  }

  bool get isTrained => _isTrained;
  int get vocabularySize => _vocabulary.length;
}
