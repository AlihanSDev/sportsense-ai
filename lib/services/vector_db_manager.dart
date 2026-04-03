import 'qdrant_service.dart';
import 'local_vector_db.dart';

/// Менеджер векторных баз данных с автоматическим fallback.
/// 
/// Приоритет:
/// 1. Qdrant (основная база)
/// 2. LocalVectorDatabase (резервная локальная база)
/// 
/// Автоматически переключается на локальную базу при:
/// - Отсутствии подключения к Qdrant
/// - Ошибках доступа к Qdrant
/// - Настройке useLocalOnly = true
class VectorDatabaseManager {
  final QdrantService? _qdrantService;
  final LocalVectorDatabase _localDb;
  final bool useLocalOnly;

  bool _isQdrantAvailable = false;
  bool _initialized = false;

  VectorDatabaseManager({
    QdrantService? qdrantService,
    LocalVectorDatabase? localDb,
    this.useLocalOnly = false,
  })  : _qdrantService = qdrantService,
        _localDb = localDb ?? LocalVectorDatabase();

  /// Инициализация менеджера.
  Future<void> initialize() async {
    if (_initialized) return;

    // Инициализация локальной базы
    await _localDb.initialize();

    // Проверка доступности Qdrant
    if (!useLocalOnly && _qdrantService != null) {
      _isQdrantAvailable = await _qdrantService.isAvailable();
      if (_isQdrantAvailable) {
        print('✓ Qdrant доступен');
        await _qdrantService.createDefaultCollections();
      } else {
        print('⚠ Qdrant недоступен, используется локальная база');
      }
    } else {
      print('ℹ Используется локальная векторная база');
    }

    _initialized = true;
  }

  /// Создание коллекции.
  Future<bool> createCollection({
    required String name,
    required int vectorSize,
    String distanceMetric = 'Cosine',
  }) async {
    if (!_initialized) await initialize();

    bool success = false;

    // Попытка создать в Qdrant
    if (_useQdrant && _qdrantService != null) {
      success = await _qdrantService.createCollection(
        collectionName: name,
        vectorSize: vectorSize,
        distance: distanceMetric,
      );
    }

    // Создание в локальной базе (всегда)
    try {
      _localDb.createCollection(
        name: name,
        vectorSize: vectorSize,
        distanceMetric: distanceMetric,
      );
      success = true;
    } catch (e) {
      // Коллекция уже существует
      if (e is ArgumentError && e.message.contains('already exists')) {
        success = true;
      }
    }

    return success;
  }

  /// Добавление точки.
  Future<bool> upsert({
    required String collectionName,
    required int id,
    required List<double> vector,
    Map<String, dynamic>? payload,
  }) async {
    if (!_initialized) await initialize();

    bool success = false;

    // Попытка добавить в Qdrant
    if (_useQdrant && _qdrantService != null) {
      success = await _qdrantService.upsertPoint(
        collectionName: collectionName,
        id: id,
        vector: vector,
        payload: payload,
      );
    }

    // Добавление в локальную базу (всегда)
    final localSuccess = _localDb.upsert(
      collectionName: collectionName,
      id: id,
      vector: vector,
      payload: payload,
    );

    return success || localSuccess;
  }

  /// Поиск по вектору.
  Future<List<Map<String, dynamic>>?> search({
    required String collectionName,
    required List<double> vector,
    int limit = 10,
  }) async {
    if (!_initialized) await initialize();

    // Попытка поиска в Qdrant
    if (_useQdrant && _qdrantService != null) {
      try {
        final results = await _qdrantService.search(
          collectionName: collectionName,
          vector: vector,
          limit: limit,
        );
        if (results != null && results.isNotEmpty) {
          return results;
        }
      } catch (e) {
        print('⚠ Ошибка поиска в Qdrant: $e');
      }
    }

    // Поиск в локальной базе (fallback)
    return _localDb.search(
      collectionName: collectionName,
      vector: vector,
      limit: limit,
    );
  }

  /// Проверка доступности Qdrant.
  Future<bool> checkQdrantAvailability() async {
    if (useLocalOnly || _qdrantService == null) {
      _isQdrantAvailable = false;
    } else {
      _isQdrantAvailable = await _qdrantService.isAvailable();
    }
    return _isQdrantAvailable;
  }

  /// Получение локальной векторной базы данных.
  LocalVectorDatabase get localDb => _localDb;

  /// Текущий режим работы.
  String get currentMode {
    if (useLocalOnly) return 'LOCAL_ONLY';
    if (_isQdrantAvailable) return 'QDRANT';
    return 'LOCAL_FALLBACK';
  }

  /// Использовать ли Qdrant.
  bool get _useQdrant => !useLocalOnly && _isQdrantAvailable && _qdrantService != null;

  /// Статистика.
  Map<String, dynamic> get stats {
    return {
      'mode': currentMode,
      'qdrantAvailable': _isQdrantAvailable,
      'localDb': _localDb.stats,
    };
  }

  /// Сохранение локальной базы на диск.
  Future<void> saveLocalDb() async {
    await _localDb.saveToDisk();
  }

  /// Очистка ресурсов.
  void dispose() {
    _qdrantService?.dispose();
  }
}
