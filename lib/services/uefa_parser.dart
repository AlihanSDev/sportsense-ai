import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';

/// Парсер для сайта UEFA.
/// Для веба используется только HTTP-парсинг.
/// Для не-веба может использовать headless-браузер.
class UefaParser {
  final http.Client _client;

  UefaParser({http.Client? client}) : _client = client ?? http.Client();

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
  /// Для веба используется упрощённый HTTP-парсинг.
  /// URL: https://www.uefa.com/nationalassociations/uefarankings/club/
  Future<List<Map<String, String>>> fetchRankings() async {
    if (kIsWeb) {
      return await _fetchRankingsHttp();
    } else {
      return await _fetchRankingsPuppeteer();
    }
  }

  /// Упрощённый парсинг через HTTP (для веба).
  Future<List<Map<String, String>>> _fetchRankingsHttp() async {
    try {
      final uri = Uri.parse('https://www.uefa.com/nationalassociations/uefarankings/club/');
      final resp = await _client.get(uri);
      
      if (resp.statusCode != 200) {
        print('⚠️ HTTP статус: ${resp.statusCode}');
        return [];
      }

      final document = parse(resp.body);
      final rankings = <Map<String, String>>[];

      // Поиск таблиц с рейтингом
      for (var table in document.querySelectorAll('table')) {
        final rows = table.querySelectorAll('tr');
        for (var row in rows) {
          final cells = row.querySelectorAll('td, th');
          if (cells.length >= 2) {
            final rowMap = <String, String>{};
            for (int i = 0; i < cells.length; i++) {
              rowMap['col_$i'] = cells[i].text.trim();
            }
            if (rowMap.isNotEmpty) {
              rankings.add(rowMap);
            }
          }
        }
      }

      // Поиск элементов с данными клубов
      if (rankings.isEmpty) {
        for (var element in document.querySelectorAll('[class*="club"], [class*="team"], [class*="rank"]')) {
          final text = element.text.trim();
          if (text.isNotEmpty && text.length > 3) {
            rankings.add({'club': text});
          }
        }
      }

      print('📊 Найдено ${rankings.length} записей (HTTP парсинг)');
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

  bool _looksLikeMatch(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.contains(' vs ') ||
        (lower.contains('-') && RegExp(r"\d").hasMatch(lower));
  }
}
