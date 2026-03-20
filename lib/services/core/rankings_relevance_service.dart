import 'dart:math' show sqrt;
import 'package:flutter/material.dart';

/// Сервис для определения релевантности запроса к теме Rankings.
/// Возвращает уровень схожести для окрашивания текста бота.
class RankingsRelevanceService {
  // Триггерные слова для Rankings (высокий приоритет)
  static const _highPriorityTriggers = [
    'ranking', 'rankings', 'rank',
    'рейтинг', 'рейтинги', 'ранг', 'ранги',
    'uefa ranking', 'uefa rankings',
    'уефа рейтинг', 'уефа рейтинги',
    'клубный рейтинг', 'рейтинг клубов',
    'страновой рейтинг',
    'uefa table', 'uefa standings',
    'уефа таблица',
    'uefa coefficient', 'uefa coefficients',
    'коэффициент', 'коэффициенты',
    'коэффициент уефа',
  ];

  // Триггерные слова для Rankings (средний приоритет - отдалённо похоже)
  static const _mediumPriorityTriggers = [
    'table', 'tables', 'standings',
    'таблица', 'таблицы', 'позиция', 'позиции',
    'место', 'места', 'топ', 'top',
    'leader', 'leaders', 'leading',
    'лидер', 'лидеры', 'возглавляет',
    'position', 'positions',
    'eurocup', 'european', 'uefa',
    'еврокуб', 'европей', 'уефа',
    'club', 'clubs', 'team', 'teams',
    'клуб', 'клубы', 'команда', 'команды',
  ];

  /// Проверка запроса на схожесть с Rankings.
  /// Возвращает уровень релевантности:
  /// - 2.0 = высокая схожесть (зелёный цвет)
  /// - 1.0 = средняя схожесть (оранжевый/жёлтый цвет)
  /// - 0.0 = нет схожести (обычный цвет)
  static double checkRelevance(String query) {
    final lowerQuery = query.toLowerCase().trim();
    
    if (lowerQuery.isEmpty) return 0.0;

    // Проверка высокоскоростных триггеров
    for (final trigger in _highPriorityTriggers) {
      if (lowerQuery.contains(trigger)) {
        return 2.0; // Высокая схожесть
      }
    }

    // Проверка среднескоростных триггеров
    for (final trigger in _mediumPriorityTriggers) {
      if (lowerQuery.contains(trigger)) {
        return 1.0; // Средняя схожесть
      }
    }

    // Вычисляем косинусную схожесть с эталонными запросами
    final similarity = _calculateCosineSimilarity(lowerQuery);
    
    if (similarity > 0.6) {
      return 2.0; // Высокая схожесть
    } else if (similarity > 0.3) {
      return 1.0; // Средняя схожесть
    }

    return 0.0; // Нет схожести
  }

  /// Расчёт косинусной схожести с эталонными запросами Rankings.
  static double _calculateCosineSimilarity(String query) {
    // Эталонные запросы для сравнения
    final referenceQueries = [
      'show uefa club ranking',
      'uefa coefficient table',
      'рейтинг клубов уефа',
      'таблица коэффициентов уефа',
      'uefa rankings 2025',
      'еврокубковый рейтинг',
    ];

    double maxSimilarity = 0.0;

    for (final reference in referenceQueries) {
      final similarity = _cosineSimilarity(query, reference.toLowerCase());
      if (similarity > maxSimilarity) {
        maxSimilarity = similarity;
      }
    }

    return maxSimilarity;
  }

  /// Косинусная схожесть между двумя строками.
  static double _cosineSimilarity(String a, String b) {
    final vectorA = _textToVector(a);
    final vectorB = _textToVector(b);

    // Скалярное произведение
    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    final keys = {...vectorA.keys, ...vectorB.keys};
    for (final key in keys) {
      final valA = vectorA[key] ?? 0.0;
      final valB = vectorB[key] ?? 0.0;
      dotProduct += valA * valB;
      normA += valA * valA;
      normB += valB * valB;
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Преобразование текста в вектор частот слов.
  static Map<String, double> _textToVector(String text) {
    final words = text
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty);

    final vector = <String, double>{};
    for (final word in words) {
      vector[word] = (vector[word] ?? 0) + 1;
    }

    return vector;
  }

  /// Получение цвета на основе релевантности.
  static Color getRelevanceColor(double relevance) {
    if (relevance >= 2.0) {
      return const Color(0xFF00FF00); // Ярко-зелёный
    } else if (relevance >= 1.0) {
      return const Color(0xFFFFA500); // Оранжевый
    } else {
      return const Color(0xFFFFFFFF); // Белый (обычный)
    }
  }

  /// Получение названия уровня релевантности.
  static String getRelevanceLabel(double relevance) {
    if (relevance >= 2.0) {
      return 'HIGH (Rankings)';
    } else if (relevance >= 1.0) {
      return 'MEDIUM (Related)';
    } else {
      return 'LOW (General)';
    }
  }
}
