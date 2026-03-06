import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart';
import 'package:puppeteer/puppeteer.dart';

/// Парсер для сайта UEFA с использованием headless-браузера.
/// Извлекает данные из AG-Grid таблиц через рендеринг JavaScript.
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
  /// Извлекает данные из AG-Grid таблицы через headless-браузер.
  /// URL: https://www.uefa.com/nationalassociations/uefarankings/club/
  Future<List<Map<String, String>>> fetchRankings() async {
    Browser? browser;
    try {
      browser = await puppeteer.launch(
        headless: true,
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
      );
      final page = await browser.newPage();
      
      // Переходим на страницу рейтинга клубов UEFA
      final rankingsUrl = 'https://www.uefa.com/nationalassociations/uefarankings/club/';
      
      await page.goto(
        rankingsUrl,
        wait: Until.domContentLoaded,
        timeout: Duration(seconds: 30),
      );
      
      // Ждём загрузки AG-Grid таблицы
      await page.waitForSelector(
        'div.ag-center-cols-container, div.ag-root-wrapper, [role="rowgroup"]',
        timeout: Duration(seconds: 20),
      );
      
      // Дополнительная задержка для рендеринга данных
      await Future.delayed(Duration(seconds: 5));

      final content = await page.content;
      final document = parse(content);

      final rankings = <Map<String, String>>[];
      
      // Ищем контейнер AG-Grid и строки внутри
      final gridContainers = document.querySelectorAll(
        'div.ag-center-cols-container, div.ag-root-wrapper, [role="rowgroup"]'
      );
      
      if (gridContainers.isEmpty) {
        return rankings;
      }

      // Извлекаем все строки таблицы из первого найденного контейнера
      for (var gridContainer in gridContainers) {
        for (var row in gridContainer.querySelectorAll('div[role="row"]')) {
          final rowMap = <String, String>{};
          
          // Извлекаем ячейки из строки
          for (var cell in row.querySelectorAll('div.ag-cell')) {
            final colId = cell.attributes['col-id'];
            if (colId == null) continue;
            
            // Ищем span с классом ag-cell-value внутри ячейки
            final valueSpan = cell.querySelector('span.ag-cell-value');
            final value = valueSpan?.text.trim() ?? cell.text.trim();
            
            if (value.isNotEmpty) {
              rowMap[colId] = value;
            }
          }
          
          if (rowMap.isNotEmpty) {
            rankings.add(rowMap);
          }
        }
      }
      
      return rankings;
    } finally {
      await browser?.close();
    }
  }

  bool _looksLikeMatch(String text) {
    if (text.isEmpty) return false;
    final lower = text.toLowerCase();
    return lower.contains(' vs ') ||
        (lower.contains('-') && RegExp(r"\d").hasMatch(lower));
  }
}
