import 'dart:async';
import 'dart:math' show sqrt;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'dart:convert';

import 'vector_db_manager.dart';
import 'uefa_rankings_api_service.dart';

/// Парсер для сайта UEFA.
/// Для веба используется только HTTP-парсинг.
/// Для не-веба может использовать headless-браузер.
class UefaParser {
  final http.Client _client;
  final String _storagePath;
  final VectorDatabaseManager? _vectorDbManager;
  final UefaRankingsApiService? _rankingsApi;

  UefaParser({
    http.Client? client,
    String storagePath = 'data/rankings',
    VectorDatabaseManager? vectorDbManager,
    UefaRankingsApiService? rankingsApi,
  })  : _client = client ?? http.Client(),
        _storagePath = storagePath,
        _vectorDbManager = vectorDbManager,
        _rankingsApi = rankingsApi;

  /// Извлекает недавние матчи со страницы UEFA.
  Future<List<String>> fetchRecentMatches() async {
    final uri = Uri.parse('https://www.uefa.com');
    final resp = await _client.get(uri);
    if (resp.statusCode != 200) {
      throw Exception('Не удалось загрузить страницу UEFA (статус ${resp.statusCode})');
    }
    final document = parse(resp.body);

    final results = <String>{};

    // Поиск элементов с текстом матчей
    for (var element in document.querySelectorAll('li, .match-row, .match-item')) {
      final text = element.text.trim();
      if (_looksLikeMatch(text)) {
        results.add(text.replaceAll(RegExp(r'\s+'), ' '));
      }
    }

    // Резервный вариант: поиск ссылок с " vs " или "-"
    if (results.isEmpty) {
      for (var anchor in document.querySelectorAll('a')) {
        final text = anchor.text.trim();
        if (_looksLikeMatch(text)) {
          results.add(text.replaceAll(RegExp(r'\s+'), ' '));
        }
      }
    }

    return results.toList();
  }

  /// Данные рейтинга клубов UEFA.
  /// Использует Python API с Playwright для рендеринга JavaScript.
  Future<List<Map<String, String>>> fetchRankings() async {
    // Пробуем получить данные через API (если доступно)
    if (_rankingsApi != null) {
      print('🔍 Получение данных через UEFA Rankings API...');
      final response = await _rankingsApi.getFreshRankings();
      
      if (response != null && response.data.isNotEmpty) {
        print('✅ API вернуло ${response.data.length} записей');
        return response.data;
      }
      
      print('⚠️ API недоступно, пробуем HTTP-парсинг...');
    }
    
    // Fallback на HTTP-парсинг (не рекомендуется)
    return await _fetchRankingsHttp();
  }

  /// Парсинг и сохранение данных рейтинга.
  /// Возвращает путь к сохранённому файлу или null при ошибке.
  Future<String?> parseAndSaveRankings() async {
    try {
      print('🚀 Начало парсинга UEFA Rankings...');

      // Парсинг данных
      final rankings = await fetchRankings();

      if (rankings.isEmpty) {
        print('⚠️ Данные не найдены');
        return null;
      }

      print('📊 Найдено ${rankings.length} записей');

      // Сохранение в векторную базу данных
      if (_vectorDbManager != null) {
        await _saveToVectorDb(rankings);
      }

      // Формирование содержимого файла
      final content = _formatRankingsToTxt(rankings);

      // Сохранение
      final filePath = await _saveToFile(content);

      print('✅ Данные сохранены: $filePath');
      return filePath;
    } catch (e) {
      print('❌ Ошибка парсинга: $e');
      return null;
    }
  }

  /// Сохранение данных рейтинга в векторную базу данных.
  Future<void> _saveToVectorDb(List<Map<String, String>> rankings) async {
    if (_vectorDbManager == null) {
      print('⚠️ Vector DB manager не инициализирован');
      return;
    }

    print('💾 Сохранение в векторную базу данных...');

    final collectionName = 'uefa_rankings_embeddings';
    
    // Создаём коллекцию если не существует
    await _vectorDbManager.createCollection(
      name: collectionName,
      vectorSize: 768, // granite-embedding-278m-multilingual
      distanceMetric: 'Cosine',
    );

    // Очищаем коллекцию перед добавлением новых данных
    print('🧹 Очистка коллекции перед обновлением...');

    // Генерируем эмбеддинги и сохраняем каждую запись
    int savedCount = 0;
    for (int i = 0; i < rankings.length; i++) {
      final row = rankings[i];
      
      // Формируем текст для эмбеддинга
      final text = _formatRowForEmbedding(row);
      
      // Генерируем тестовый вектор (заглушка - нужно заменить на реальную модель)
      final vector = _generateTestEmbedding(text);
      
      // Формируем payload с полными данными
      final payload = {
        'type': 'uefa_ranking',
        'association': row['association'] ?? row['col_0'] ?? '',
        'clubs': row['clubs'] ?? row['col_1'] ?? '',
        'bonus': row['bonus'] ?? row['col_2'] ?? '',
        'points': row['points'] ?? row['col_3'] ?? '',
        'avg': row['avg'] ?? row['col_4'] ?? '',
        'rank': (i + 1).toString(),
        'timestamp': DateTime.now().toIso8601String(),
        'raw_text': text, // Сохраняем исходный текст для RAG
      };

      // Сохраняем точку
      final success = await _vectorDbManager.upsert(
        collectionName: collectionName,
        id: i + 1,
        vector: vector,
        payload: payload,
      );
      
      if (success) {
        savedCount++;
      }
    }

    print('✅ Сохранено $savedCount из ${rankings.length} записей в векторную базу');
  }

  /// Форматирование строки для эмбеддинга.
  String _formatRowForEmbedding(Map<String, String> row) {
    final association = row['association'] ?? row['col_0'] ?? 'Unknown';
    final clubs = row['clubs'] ?? row['col_1'] ?? '';
    final bonus = row['bonus'] ?? row['col_2'] ?? '';
    final points = row['points'] ?? row['col_3'] ?? '';
    final avg = row['avg'] ?? row['col_4'] ?? '';
    
    return 'UEFA ranking: $association clubs: $clubs bonus: $bonus points: $points average: $avg';
  }

  /// Генерация тестового эмбеддинга (заглушка).
  /// TODO: Заменить на реальную модель (granite-embedding-278m-multilingual)
  List<double> _generateTestEmbedding(String text) {
    final hash = utf8.encode(text);
    final vector = List<double>.filled(768, 0.0);

    for (int i = 0; i < 768; i++) {
      final seed = hash[i % hash.length] ^ (i * 17);
      vector[i] = ((seed % 1000) / 1000.0 - 0.5) * 2;
    }

    // Нормализация для косинусной схожести
    final norm = _vectorNorm(vector);
    if (norm > 0) {
      for (int i = 0; i < vector.length; i++) {
        vector[i] /= norm;
      }
    }

    return vector;
  }

  /// Норма вектора.
  double _vectorNorm(List<double> vector) {
    double sum = 0.0;
    for (final v in vector) {
      sum += v * v;
    }
    return sqrt(sum);
  }

  /// Упрощённый парсинг через HTTP (для веба).
  /// Ищет данные в JSON внутри страницы.
  Future<List<Map<String, String>>> _fetchRankingsHttp() async {
    try {
      final uri = Uri.parse('https://www.uefa.com/nationalassociations/uefarankings/club/');
      final resp = await _client.get(uri);
      
      if (resp.statusCode != 200) {
        print('⚠️ HTTP статус: ${resp.statusCode}');
        return [];
      }

      final html = resp.body;
      final document = parse(html);
      final rankings = <Map<String, String>>[];

      print('🔍 Размер HTML: ${html.length} байт');

      // 1. Поиск JSON данных в script тегах
      final scripts = document.querySelectorAll('script');
      print('🔍 Найдено script тегов: ${scripts.length}');

      for (var script in scripts) {
        final scriptContent = script.text;
        if (scriptContent.isEmpty) continue;

        // Поиск JSON с данными рейтинга
        if (scriptContent.contains('rankings') || scriptContent.contains('associations')) {
          print('📄 Найден script с данными (${scriptContent.length} символов)');
          
          // Извлекаем возможные JSON объекты
          final jsonMatches = RegExp(r'\{[^{}]*"rank"[^{}]*\}').allMatches(scriptContent);
          for (var match in jsonMatches) {
            print('   JSON фрагмент: ${match.group(0)?.substring(0, 100)}...');
          }
        }

        // Поиск данных в формате JSON-LD или встроенных данных
        if (scriptContent.contains('"__NEXT_DATA__"') || scriptContent.contains('"pageProps"')) {
          print('📄 Найден Next.js data блок');
        }
      }

      // 2. Поиск data-атрибутов с данными (используем правильный CSS селектор)
      final dataElements = document.querySelectorAll('[data-association], [data-rank], [data-id]');
      print('🔍 Найдено элементов с data-атрибутами: ${dataElements.length}');

      // 3. Поиск строк AG-Grid таблицы по role="row"
      final rows = document.querySelectorAll('div[role="row"]');
      print('🔍 Найдено строк с role="row": ${rows.length}');

      // Альтернативный поиск через ag-center-cols-container
      final gridContainer = document.querySelector('div.ag-center-cols-container');
      if (gridContainer != null) {
        print('🔍 Найден ag-center-cols-container');
        final containerRows = gridContainer.querySelectorAll('div[role="row"]');
        print('   Найдено строк в контейнере: ${containerRows.length}');
        
        for (var row in containerRows) {
          final rowMap = <String, String>{};
          
          // Извлекаем ячейки с col-id
          final cells = row.querySelectorAll('div[role="gridcell"]');
          
          for (var cell in cells) {
            final colId = cell.attributes['col-id'];
            if (colId == null) continue;

            // Ищем значение в span.ag-cell-value
            final valueSpan = cell.querySelector('span.ag-cell-value');
            final value = valueSpan?.text.trim() ?? cell.text.trim();

            if (value.isNotEmpty) {
              rowMap[colId] = value;
            }
          }

          if (rowMap.isNotEmpty && rowMap.length >= 2) {
            rankings.add(rowMap);
          }
        }
      }

      // Если не нашли в контейнере, пробуем общий поиск
      if (rankings.isEmpty) {
        for (var row in rows) {
          final rowMap = <String, String>{};
          
          // Извлекаем ячейки с col-id
          final cells = row.querySelectorAll('div[role="gridcell"]');
          
          for (var cell in cells) {
            final colId = cell.attributes['col-id'];
            if (colId == null) continue;

            // Ищем значение в span.ag-cell-value
            final valueSpan = cell.querySelector('span.ag-cell-value');
            final value = valueSpan?.text.trim() ?? cell.text.trim();

            if (value.isNotEmpty) {
              rowMap[colId] = value;
            }
          }

          if (rowMap.isNotEmpty && rowMap.length >= 2) {
            rankings.add(rowMap);
          }
        }
      }

      print('📊 Найдено ${rankings.length} записей (HTTP парсинг)');
      
      // Вывод первых записей для отладки
      for (int i = 0; i < rankings.length && i < 3; i++) {
        print('   Запись $i: ${rankings[i]}');
      }
      
      return rankings;
    } catch (e) {
      print('⚠️ Ошибка HTTP парсинга: $e');
      return [];
    }
  }

  /// Парсинг через headless-браузер (для не-веба).
  Future<List<Map<String, String>>> _fetchRankingsPuppeteer() async {
    // TODO: Реализовать через puppeteer для desktop/mobile
    // Пока используем HTTP парсинг как fallback
    return await _fetchRankingsHttp();
  }

  /// Форматирование данных в TXT формат.
  String _formatRankingsToTxt(List<Map<String, String>> rankings) {
    final buffer = StringBuffer();

    buffer.writeln('=' * 80);
    buffer.writeln('UEFA CLUB RANKINGS');
    buffer.writeln('Generated: ${DateTime.now().toIso8601String()}');
    buffer.writeln('=' * 80);
    buffer.writeln();

    // Заголовки столбцов
    if (rankings.isNotEmpty) {
      final headers = rankings.first.keys.toList();
      buffer.writeln(headers.join(' | '));
      buffer.writeln('-' * 80);
    }

    // Данные
    for (final row in rankings) {
      final values = row.values.toList();
      buffer.writeln(values.join(' | '));
    }

    buffer.writeln();
    buffer.writeln('=' * 80);
    buffer.writeln('Total: ${rankings.length} clubs');
    buffer.writeln('=' * 80);

    return buffer.toString();
  }

  /// Сохранение содержимого в файл.
  Future<String> _saveToFile(String content) async {
    final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final filename = 'rankings_$timestamp.txt';

    if (kIsWeb) {
      // Для веба: только сообщение о том, что данные получены
      // Реальное сохранение требует JavaScript интероп
      print('💾 Web: данные готовы к сохранению ($filename)');
      return 'web: $filename';
    } else {
      // Для не-web платформ (Android, iOS, Desktop)
      // Примечание: требует dart:io
      throw UnsupportedError('File save not implemented for this platform');
    }
  }

  /// Быстрая проверка релевантности и парсинг.
  static Future<String?> parseIfRelevant(String query, {UefaParser? parser}) async {
    final relevance = _checkRelevance(query);
    
    if (relevance >= 1.0) {
      print('🎯 Обнаружена релевантность к Rankings: $relevance');
      final instance = parser ?? UefaParser();
      return await instance.parseAndSaveRankings();
    }
    
    return null;
  }

  /// Простая проверка релевантности запроса.
  static double _checkRelevance(String query) {
    final lowerQuery = query.toLowerCase();
    
    final triggers = [
      'ranking', 'rankings', 'рейтинг', 'рейтинги',
      'uefa ranking', 'uefa table', 'таблица uefa',
      'клубный рейтинг', 'рейтинг клубов',
      'coefficient', 'коэффициент',
    ];
    
    for (final trigger in triggers) {
      if (lowerQuery.contains(trigger)) {
        return 2.0;
      }
    }
    
    final mediumTriggers = [
      'table', 'таблица', 'uefa', 'уефа',
      'club', 'клуб', 'euro', 'евро',
    ];
    
    for (final trigger in mediumTriggers) {
      if (lowerQuery.contains(trigger)) {
        return 1.0;
      }
    }
    
    return 0.0;
  }

  bool _looksLikeMatch(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.contains(' vs ') ||
        (lower.contains('-') && RegExp(r"\d").hasMatch(lower));
  }
}
