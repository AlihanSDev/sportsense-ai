import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html_web;
import 'uefa_parser.dart';

/// Сервис для парсинга и сохранения данных UEFA Rankings.
/// Активируется при обнаружении релевантности к Rankings.
class RankingsDataParser {
  final UefaParser _parser;
  final String _storagePath;

  RankingsDataParser({
    UefaParser? parser,
    String storagePath = 'data/rankings',
  })  : _parser = parser ?? UefaParser(),
        _storagePath = storagePath;

  /// Парсинг и сохранение данных рейтинга.
  /// Возвращает путь к сохранённому файлу или null при ошибке.
  Future<String?> parseAndSave() async {
    try {
      print('🚀 Начало парсинга UEFA Rankings...');

      // Парсинг данных
      final rankings = await _parser.fetchRankings();

      if (rankings.isEmpty) {
        print('⚠️ Данные не найдены');
        return null;
      }

      print('📊 Найдено ${rankings.length} записей');

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
      // Для веба используем localStorage
      final key = 'rankings_$filename';
      html_web.window.localStorage[key] = content;
      
      // Также скачиваем файл
      final blob = html_web.Blob([content], 'text/plain');
      final url = html_web.Url.createObjectUrlFromBlob(blob);
      final anchor = html_web.AnchorElement()
        ..href = url
        ..download = filename
        ..click();
      html_web.Url.revokeObjectUrl(url);

      return 'localStorage: $filename';
    } else {
      // Для не-web платформ
      final directory = Directory(_storagePath);
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final file = File('${_storagePath}/$filename');
      await file.writeAsString(content);

      return file.path;
    }
  }

  /// Быстрая проверка релевантности и парсинг.
  static Future<String?> parseIfRelevant(String query, {RankingsDataParser? parser}) async {
    final relevance = _checkRelevance(query);
    
    if (relevance >= 1.0) {
      print('🎯 Обнаружена релевантность к Rankings: $relevance');
      final instance = parser ?? RankingsDataParser();
      return await instance.parseAndSave();
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
}
