import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Клиент для работы с локальным Qdrant векторной базой данных.
/// Поддерживает автоматический запуск Qdrant без Docker.
class QdrantClient {
  final String url;
  final String? apiKey;
  final http.Client _client;
  
  Process? _qdrantProcess;
  bool _isRunning = false;

  QdrantClient({
    String? url,
    String? apiKey,
    http.Client? client,
  })  : url = url ?? dotenv.env['QDRANT_URL'] ?? 'http://localhost:6333',
        apiKey = apiKey ?? dotenv.env['QDRANT_API_KEY'],
        _client = client ?? http.Client();

  /// Проверка доступен ли Qdrant
  Future<bool> isAvailable() async {
    try {
      final response = await _client.get(Uri.parse('$url/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Запуск локального Qdrant без Docker
  /// Требуется скачать бинарник с https://qdrant.tech/documentation/quick-start/
  Future<bool> startLocal({String? qdrantPath}) async {
    // На Web Process.start недоступен - только проверка доступности
    if (kIsWeb) {
      debugPrint('🌐 Web платформа: проверка доступности Qdrant...');
      if (await isAvailable()) {
        debugPrint('✅ Qdrant доступен на $url');
        _isRunning = true;
        return true;
      } else {
        debugPrint('❌ Qdrant недоступен на $url. Запустите сервер Qdrant.');
        return false;
      }
    }

    if (await isAvailable()) {
      debugPrint('✅ Qdrant уже запущен на $url');
      _isRunning = true;
      return true;
    }

    // Поиск бинарника Qdrant
    final binaryPath = qdrantPath ?? await _findQdrantBinary();
    
    if (binaryPath == null) {
      debugPrint('❌ Бинарник Qdrant не найден. Скачайте с: https://qdrant.tech/documentation/quick-start/');
      debugPrint('💡 Или запустите Docker: docker run -p 6333:6333 qdrant/qdrant');
      return false;
    }

    debugPrint('🚀 Запуск Qdrant: $binaryPath');
    
    try {
      _qdrantProcess = await Process.start(
        binaryPath,
        [],
        workingDirectory: Directory(binaryPath).parent.path,
        environment: {
          'QDRANT__SERVICE__GRPC_PORT': '6334',
          'QDRANT__SERVICE__HTTP_PORT': '6333',
        },
      );

      // Чтение логов
      _qdrantProcess!.stdout.listen((data) {
        if (kDebugMode) {
          debugPrint('Qdrant: ${utf8.decode(data).trim()}');
        }
      });

      _qdrantProcess!.stderr.listen((data) {
        debugPrint('Qdrant ERROR: ${utf8.decode(data).trim()}');
      });

      // Ожидание запуска (до 30 сек)
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(seconds: 1));
        if (await isAvailable()) {
          debugPrint('✅ Qdrant запущен на $url');
          _isRunning = true;
          return true;
        }
      }

      debugPrint('❌ Qdrant не запустился за 30 секунд');
      return false;
    } catch (e) {
      debugPrint('❌ Ошибка запуска Qdrant: $e');
      return false;
    }
  }

  /// Поиск бинарника Qdrant в системе
  Future<String?> _findQdrantBinary() async {
    // Проверка стандартных путей
    final possiblePaths = [
      // Windows
      'C:\\qdrant\\bin\\qdrant.exe',
      'C:\\Program Files\\qdrant\\qdrant.exe',
      '${Platform.environment['LOCALAPPDATA']}\\qdrant\\qdrant.exe',
      // macOS
      '/usr/local/bin/qdrant',
      '/opt/homebrew/bin/qdrant',
      // Linux
      '/usr/local/bin/qdrant',
      '/opt/qdrant/bin/qdrant',
      // Текущая директория
      'qdrant/bin/qdrant.exe',
      'qdrant/bin/qdrant',
      './qdrant.exe',
      './qdrant',
    ];

    for (var path in possiblePaths) {
      if (path.isEmpty) continue;
      final file = File(path);
      if (await file.exists()) {
        debugPrint('📍 Найден Qdrant: $path');
        return path;
      }
    }

    return null;
  }

  /// Остановка локального Qdrant
  Future<void> stopLocal() async {
    if (_qdrantProcess != null) {
      _qdrantProcess!.kill();
      _qdrantProcess = null;
      _isRunning = false;
      debugPrint('🛑 Qdrant остановлен');
    }
  }

  /// Создание коллекции в Qdrant
  Future<bool> createCollection({
    required String collectionName,
    int vectorSize = 384,
    String distance = 'Cosine',
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({
          'vectors': {
            'size': vectorSize,
            'distance': distance,
          },
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Коллекция $collectionName создана');
        return true;
      } else {
        debugPrint('❌ Ошибка создания коллекции: ${response.statusCode}');
        debugPrint('Ответ: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Ошибка создания коллекции: $e');
      return false;
    }
  }

  /// Проверка существования коллекции
  Future<bool> collectionExists(String collectionName) async {
    try {
      final response = await _client.get(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Добавление векторов в коллекцию
  Future<bool> upsertPoints({
    required String collectionName,
    required List<Map<String, dynamic>> points,
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$url/collections/$collectionName/points'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({
          'points': points,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = data['status'] as String?;
        if (status == 'ok') {
          debugPrint('✅ Загружено ${points.length} векторов в $collectionName');
          return true;
        }
      }
      
      debugPrint('❌ Ошибка upsert: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('❌ Ошибка upsert: $e');
      return false;
    }
  }

  /// Поиск похожих векторов
  Future<List<Map<String, dynamic>>> searchPoints({
    required String collectionName,
    required List<double> vector,
    int limit = 5,
    double threshold = 0.5,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$url/collections/$collectionName/points/search'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({
          'vector': vector,
          'limit': limit,
          'with_payload': true,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final result = data['result'] as List<dynamic>?;
        
        if (result != null) {
          // Фильтрация по threshold
          return result
              .where((item) {
                final score = (item as Map<String, dynamic>)['score'] as num?;
                return (score?.toDouble() ?? 0) >= threshold;
              })
              .cast<Map<String, dynamic>>()
              .toList();
        }
      }
      
      return [];
    } catch (e) {
      debugPrint('❌ Ошибка поиска: $e');
      return [];
    }
  }

  /// Удаление коллекции
  Future<bool> deleteCollection(String collectionName) async {
    try {
      final response = await _client.delete(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Очистка коллекции (удаление всех точек)
  Future<bool> clearCollection(String collectionName) async {
    try {
      final response = await _client.post(
        Uri.parse('$url/collections/$collectionName/points/delete'),
        headers: {
          'Content-Type': 'application/json',
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
        body: jsonEncode({'filter': {}}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Получить информацию о коллекции
  Future<Map<String, dynamic>?> getCollectionInfo(String collectionName) async {
    try {
      final response = await _client.get(
        Uri.parse('$url/collections/$collectionName'),
        headers: {
          if (apiKey != null && apiKey!.isNotEmpty) 'api-key': apiKey!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['result'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Закрытие соединения
  Future<void> dispose() async {
    await stopLocal();
    _client.close();
  }
}
