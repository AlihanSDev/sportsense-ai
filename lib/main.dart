import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// Импорты сервисов
import 'services/core/uefa_search_manager.dart';
import 'services/core/vector_db_manager.dart';
import 'services/core/user_query_vectorizer.dart';
import 'services/core/rankings_relevance_service.dart';
import 'services/core/uefa_parser.dart';
import 'services/api/qwen_api_service.dart';
import 'services/core/rankings_vector_search.dart';
import 'services/api/uefa_rankings_api_service.dart';

// Импорты виджетов
import 'widgets/space_background.dart';
import 'widgets/chat_interface.dart';

// ============================================================================
// КОНФИГУРАЦИЯ ДЛЯ SMALL PHONE COLD BOOST EMULATOR
// ============================================================================
const String DEVICE_ID = 'small_phone_cold_boost';
const String DEVICE_NAME = 'Small Phone Cold Boost';
const String DEVICE_SCREEN = '720x1280';
const String DEVICE_RAM = '1024MB';
const String DEVICE_CPU = '4 cores x86_64';
const String ANDROID_API = '36.1';

// API конфигурация для локальной разработки
const String QWEN_API_URL = 'http://127.0.0.1:5000';
const String UEFA_PARSER_API_URL = 'http://127.0.0.1:8000';
const String QDRANT_HOST = 'localhost';
const int QDRANT_PORT = 6333;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ========================================================================
  _logStartupInfo();

  // Инициализация с обработкой ошибок
  final appState = await _initializeAppState();

  if (appState == null) {
    // Аварийный запуск с минимальными сервисами
    _showEmergencyApp();
    return;
  }

  runApp(
    SpaceApp(
      vectorDbManager: appState['vectorDbManager'] as VectorDatabaseManager,
      queryVectorizer:
          appState['queryVectorizer'] as UserQueryVectorizerService,
      uefaParser: appState['uefaParser'] as UefaParser,
      qwenApi: appState['qwenApi'] as QwenApiService,
      rankingsSearch: appState['rankingsSearch'] as RankingsVectorSearch,
      rankingsApiAvailable: appState['rankingsApiAvailable'] as bool,
      qwenAvailable: appState['qwenAvailable'] as bool,
    ),
  );
}

/// Логирование информации о запуске
void _logStartupInfo() {
  print('\n═════════════════════════════════════════════════════════════════');
  print('🚀 SPORTSENSE-AI INITIALIZATION');
  print('═════════════════════════════════════════════════════════════════');
  print('📱 Device: $DEVICE_NAME');
  print('   ID: $DEVICE_ID');
  print('   Screen: $DEVICE_SCREEN');
  print('   RAM: $DEVICE_RAM');
  print('   CPU: $DEVICE_CPU');
  print('   Android API: $ANDROID_API');
  final platformName = kIsWeb
      ? 'Web'
      : (defaultTargetPlatform == TargetPlatform.android
            ? 'Android'
            : defaultTargetPlatform == TargetPlatform.iOS
            ? 'iOS'
            : defaultTargetPlatform == TargetPlatform.macOS
            ? 'macOS'
            : defaultTargetPlatform == TargetPlatform.windows
            ? 'Windows'
            : defaultTargetPlatform == TargetPlatform.linux
            ? 'Linux'
            : defaultTargetPlatform == TargetPlatform.fuchsia
            ? 'Fuchsia'
            : 'Unknown');
  print('🔧 Platform: $platformName');
  print(
    '⚙️ Mode: ${const bool.fromEnvironment('dart.vm.product', defaultValue: false) ? 'RELEASE' : 'DEBUG'}',
  );
  print('🌐 Qwen API: $QWEN_API_URL');
  print('📊 Qdrant: $QDRANT_HOST:$QDRANT_PORT');
  print('═════════════════════════════════════════════════════════════════\n');
}

/// Инициализация всех сервисов приложения
Future<Map<String, dynamic>?> _initializeAppState() async {
  try {
    print('[1/6] 🗄️  Инициализация векторной базы данных...');
    final vectorDbManager = VectorDatabaseManager(useLocalOnly: true);
    await vectorDbManager.initialize();
    print('     ✅ Векторная база данных готова\n');

    print('[2/6] 🔍 Инициализация сервиса векторизации запросов...');
    final queryVectorizer = UserQueryVectorizerService(
      dbManager: vectorDbManager,
    );
    await queryVectorizer.initialize();
    print('     ✅ Сервис векторизации готов\n');

    print('[3/6] 📊 Проверка UEFA Rankings API ($UEFA_PARSER_API_URL)...');
    final rankingsApi = UefaRankingsApiService();
    final rankingsApiAvailable = await rankingsApi.isAvailable();
    if (rankingsApiAvailable) {
      print('     ✅ UEFA Rankings API доступен\n');
    } else {
      print('     ⚠️  UEFA Rankings API недоступен');
      print('     💡 Запустите: python scripts/uefa_parser_api.py\n');
    }

    print('[4/6] ⚽ Инициализация UFC парсера...');
    final uefaParser = UefaParser(
      vectorDbManager: vectorDbManager,
      rankingsApi: rankingsApi,
    );
    print('     ✅ UEFA парсер готов\n');

    print('[5/6] 🔎 Инициализация поиска по рейтингам...');
    final rankingsSearch = RankingsVectorSearch(dbManager: vectorDbManager);
    print('     ✅ Поиск по рейтингам готов\n');

    print('[6/6] 🤖 Проверка Qwen API ($QWEN_API_URL)...');
    final qwenApi = QwenApiService(baseUrl: QWEN_API_URL);
    final qwenAvailable = await qwenApi.isAvailable();
    if (qwenAvailable) {
      print('     ✅ Qwen API доступен\n');
    } else {
      print('     ⚠️  Qwen API недоступен');
      print('     💡 Запустите: python scripts/qwen_api.py\n');
    }

    print('═════════════════════════════════════════════════════════════════');
    print('✅ ВСЕ СЕРВИСЫ ИНИЦИАЛИЗИРОВАНЫ УСПЕШНО');
    print(
      '═════════════════════════════════════════════════════════════════\n',
    );

    return {
      'vectorDbManager': vectorDbManager,
      'queryVectorizer': queryVectorizer,
      'uefaParser': uefaParser,
      'qwenApi': qwenApi,
      'rankingsSearch': rankingsSearch,
      'rankingsApiAvailable': rankingsApiAvailable,
      'qwenAvailable': qwenAvailable,
    };
  } catch (e, stackTrace) {
    print('\n❌ КРИТИЧЕСКАЯ ОШИБКА ПРИ ИНИЦИАЛИЗАЦИИ:');
    print('Error: $e');
    print('StackTrace: $stackTrace\n');
    return null;
  }
}

/// Аварийное приложение при ошибке инициализации
void _showEmergencyApp() {
  runApp(
    MaterialApp(
      title: 'Sportsense - Emergency Mode',
      home: Scaffold(
        backgroundColor: Colors.black87,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 24),
              const Text(
                'Ошибка инициализации приложения',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  'Проверьте логи консоли для получения информации об ошибке.\n\n'
                  'Убедитесь, что запущены все необходимые сервисы:\n'
                  '• python scripts/qwen_api.py\n'
                  '• python scripts/uefa_parser_api.py',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  print('Попытка повторной инициализации...');
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Повторить'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class SpaceApp extends StatelessWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;

  const SpaceApp({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sportsense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.dark(
          primary: Colors.white.withOpacity(0.9),
          secondary: Colors.white.withOpacity(0.7),
          surface: Colors.white.withOpacity(0.05),
          error: const Color(0xFFB37B7B),
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.white,
          onError: const Color(0xFFE0C0C0),
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: HomePage(
        vectorDbManager: vectorDbManager,
        queryVectorizer: queryVectorizer,
        uefaParser: uefaParser,
        qwenApi: qwenApi,
        rankingsSearch: rankingsSearch,
        rankingsApiAvailable: rankingsApiAvailable,
        qwenAvailable: qwenAvailable,
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;

  const HomePage({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final UefaSearchManager _uefaSearchManager;
  late final UserQueryVectorizerService _queryVectorizer;
  late final UefaParser _uefaParser;
  late final QwenApiService _qwenApi;
  late final RankingsVectorSearch _rankingsSearch;
  final List<ChatMessage> _messages = [
    ChatMessage(
      text:
          'Здравствуйте! Я ваш ассистент Sportsense. Чем я могу вам помочь сегодня?',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _uefaSearchManager = UefaSearchManager();
    _uefaSearchManager.initialize();
    _uefaSearchManager.addListener(_onUefaSearchChanged);
    _queryVectorizer = widget.queryVectorizer;
    _uefaParser = widget.uefaParser;
    _qwenApi = widget.qwenApi;
    _rankingsSearch = widget.rankingsSearch;

    // Добавляем сообщения о статусе сервисов
    if (!widget.rankingsApiAvailable) {
      _messages.add(
        ChatMessage(
          text:
              '⚠️ UEFA Rankings API недоступен.\nЗапустите:\n```\npython scripts/uefa_parser_api.py\n```\n\nПока данные не будут загружены.',
          isUser: false,
          textColor: const Color(0xFFB37B7B),
        ),
      );
    }

    if (!widget.qwenAvailable) {
      _messages.add(
        ChatMessage(
          text:
              '⚠️ Qwen API недоступен.\nЗапустите:\n```\npython scripts/qwen_api.py\n```\n\nПока используется тестовый режим.',
          isUser: false,
          textColor: const Color(0xFFB37B7B),
        ),
      );
    }
  }

  void _onUefaSearchChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    _uefaSearchManager.removeListener(_onUefaSearchChanged);
    _uefaSearchManager.dispose();
    super.dispose();
  }

  Future<void> _sendMessage(String text) async {
    // Проверка на триггеры UEFA
    final hasUefaTrigger = await _uefaSearchManager.interceptQuery(text);

    if (hasUefaTrigger) {
      // Ждём пока анимация не завершится
      while (_uefaSearchManager.isSearching) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    // Проверка релевантности запроса к Rankings
    final relevance = RankingsRelevanceService.checkRelevance(text);
    final textColor = RankingsRelevanceService.getRelevanceColor(relevance);

    // RAG пайплайн: Парсинг → Векторная база → Поиск → Qwen с контекстом
    String? parsingStatus;
    String ragContext = '';

    // Шаг 1: Если высокая релевантность — парсим и сохраняем в векторную базу
    if (relevance >= 2.0) {
      parsingStatus = '🔄 RAG: Парсинг UEFA Rankings...';
      print('🔍 RAG: Запрос релевантен Rankings, начинаем парсинг...');

      // Парсим и сохраняем в векторную базу
      await _uefaParser.parseAndSaveRankings();

      // Небольшая задержка чтобы данные успели сохраниться
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Шаг 2: Поиск релевантных данных в векторной базе
    if (relevance >= 1.0) {
      print('🔍 RAG: Поиск данных в векторной базе...');
      ragContext = await _rankingsSearch.getRagContext(text, limit: 10);

      if (ragContext.isEmpty) {
        print('⚠️ RAG: Данные не найдены в векторной базе');
      } else {
        print('✅ RAG: Контекст получен (${ragContext.length} символов)');
      }
    }

    // Шаг 3: Запрос к Qwen API с RAG контекстом
    String botResponse;
    if (widget.qwenAvailable) {
      print('🤖 RAG: Отправка запроса к Qwen с контекстом...');

      // Запрос к реальной модели с контекстом
      final qwenResponse = await _qwenApi.chat(
        text,
        context: ragContext.isNotEmpty ? ragContext : null,
        maxTokens: 1024,
      );

      if (qwenResponse != null) {
        botResponse = qwenResponse.response;
        print('✅ RAG: Ответ получен (${qwenResponse.tokensUsed} токенов)');
      } else {
        botResponse = '❌ Ошибка при получении ответа от Qwen.';
        print('❌ RAG: Ошибка получения ответа');
      }
    } else {
      // Тестовый режим с RAG контекстом
      botResponse = '**Тестовый режим** (Qwen API недоступен)\n\n';

      if (ragContext.isNotEmpty) {
        botResponse += '**Найдено в базе:**\n';
        botResponse += '$ragContext\n\n';
      } else {
        botResponse += 'Данные в базе не найдены.\n\n';
      }

      botResponse += '**Ваш запрос:** "$text"\n';
      botResponse +=
          '**Релевантность:** ${RankingsRelevanceService.getRelevanceLabel(relevance)}\n\n';
    }

    // Формируем полный ответ
    String fullResponse;
    if (parsingStatus != null && ragContext.isNotEmpty) {
      fullResponse = '$parsingStatus\n\n$botResponse';
    } else if (parsingStatus != null) {
      fullResponse = '$parsingStatus\n\n$botResponse';
    } else if (ragContext.isNotEmpty && widget.qwenAvailable) {
      fullResponse = '**Данные из базы**\n\n$botResponse';
    } else {
      fullResponse = botResponse;
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(text: fullResponse, isUser: false, textColor: textColor),
        );
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SpaceBackground(
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Заголовок
            Column(
              children: [
                Text(
                  'Sportsense',
                  style: GoogleFonts.inter(
                    fontSize: 36,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 2,
                    decoration: TextDecoration.none,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'AI Assistant',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w300,
                    color: Colors.white.withOpacity(0.6),
                    letterSpacing: 1,
                    decoration: TextDecoration.none,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Чат
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ChatInterface(
                    messages: _messages,
                    onSendMessage: _sendMessage,
                    onClear: () {
                      setState(() {
                        _messages.clear();
                        _isLoading = false;
                      });
                      _uefaSearchManager.reset();
                    },
                    isLoading: _isLoading,
                    showSearch: _uefaSearchManager.isSearching,
                    searchError: _uefaSearchManager.hasError
                        ? _uefaSearchManager.errorMessage
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
