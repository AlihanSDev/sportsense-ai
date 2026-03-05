import 'dart:math';

/// Утилиты для работы с векторами
class VectorUtils {
  /// Генерация случайного вектора (для тестов)
  static List<double> generateRandomVector(int size, {int seed = 42}) {
    final random = Random(seed);
    return List.generate(size, (_) => (random.nextDouble() * 2 - 1));
  }

  /// Нормализация вектора
  static List<double> normalize(List<double> vector) {
    final magnitude = sqrt(vector.fold<double>(
      0,
      (sum, value) => sum + value * value,
    ));
    if (magnitude == 0) return vector;
    return vector.map((v) => v / magnitude).toList();
  }

  /// Косинусное сходство между двумя векторами
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError('Векторы должны иметь одинаковую длину');
    }

    double dotProduct = 0;
    double magnitudeA = 0;
    double magnitudeB = 0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      magnitudeA += a[i] * a[i];
      magnitudeB += b[i] * b[i];
    }

    magnitudeA = sqrt(magnitudeA);
    magnitudeB = sqrt(magnitudeB);

    if (magnitudeA == 0 || magnitudeB == 0) return 0;

    return dotProduct / (magnitudeA * magnitudeB);
  }
}
