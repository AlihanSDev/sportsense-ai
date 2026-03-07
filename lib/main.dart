import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/uefa_search_manager.dart';
import 'services/vector_db_manager.dart';
import 'services/user_query_vectorizer.dart';
import 'services/rankings_relevance_service.dart';
import 'services/uefa_parser.dart';
import 'services/qwen_api_service.dart';
import 'widgets/space_background.dart';
import 'widgets/chat_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация векторной базы данных
  final vectorDbManager = VectorDatabaseManager();
  await vectorDbManager.initialize();

  // Инициализация сервиса векторизации запросов
  final queryVectorizer = UserQueryVectorizerService(dbManager: vectorDbManager);
  await queryVectorizer.initialize();

  // Инициализация парсера UEFA с векторной базой
  final uefaParser = UefaParser(vectorDbManager: vectorDbManager);

  // Инициализация Qwen API
  final qwenApi = QwenApiService();
  final qwenAvailable = await qwenApi.isAvailable();
  print(qwenAvailable ? '✅ Qwen API доступен' : '⚠️ Qwen API недоступен (запустите python scripts/qwen_api.py)');

  runApp(SpaceApp(
    vectorDbManager: vectorDbManager,
    queryVectorizer: queryVectorizer,
    uefaParser: uefaParser,
    qwenApi: qwenApi,
    qwenAvailable: qwenAvailable,
  ));
}

class SpaceApp extends StatelessWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final bool qwenAvailable;

  const SpaceApp({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.qwenAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sportsense',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: HomePage(
        vectorDbManager: vectorDbManager,
        queryVectorizer: queryVectorizer,
        uefaParser: uefaParser,
        qwenApi: qwenApi,
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
  final bool qwenAvailable;

  const HomePage({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
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
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Здравствуйте! Я ваш ИИ-ассистент Sportsense. Чем я могу вам помочь сегодня?',
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
    
    // Добавляем сообщение о статусе Qwen
    if (!widget.qwenAvailable) {
      _messages.add(ChatMessage(
        text: '⚠️ Qwen API недоступен. Запустите:\npython scripts/qwen_api.py\n\nПока используется тестовый режим.',
        isUser: false,
        textColor: Colors.orange,
      ));
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

    // Векторизация запроса (для тестов)
    final vectorizationResult = await _queryVectorizer.vectorizeQuery(text);

    // Проверка релевантности запроса к Rankings
    final relevance = RankingsRelevanceService.checkRelevance(text);
    final textColor = RankingsRelevanceService.getRelevanceColor(relevance);

    // Если высокая релевантность к Rankings — запускаем парсинг
    String? parsingStatus;
    if (relevance >= 2.0) {
      parsingStatus = '🔄 Парсинг UEFA Rankings...';
      // Запускаем парсинг без ожидания (асинхронно)
      _uefaParser.parseAndSaveRankings();
    }

    // Запрос к Qwen API
    String botResponse;
    if (widget.qwenAvailable) {
      // Запрос к реальной модели
      final qwenResponse = await _qwenApi.chat(text);
      if (qwenResponse != null) {
        botResponse = qwenResponse.response;
      } else {
        botResponse = '❌ Ошибка при получении ответа от Qwen.';
      }
    } else {
      // Тестовый режим (заглушка)
      botResponse = '🤖 Тестовый ответ (Qwen недоступен).\n\nЗапрос: "$text"\nРелевантность: ${RankingsRelevanceService.getRelevanceLabel(relevance)}\n\nДля реальных ответов запустите:\npython scripts/qwen_api.py';
    }

    // Формируем полный ответ
    final fullResponse = parsingStatus != null 
        ? '$parsingStatus\n\n$botResponse'
        : botResponse;

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      setState(() {
        _messages.add(ChatMessage(
          text: fullResponse,
          isUser: false,
          textColor: textColor,
        ));
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
            const SizedBox(height: 16),

            // Заголовок с эффектом свечения
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [
                  Color(0xFF00D4FF),
                  Color(0xFF7C4DFF),
                  Color(0xFFE040FB),
                ],
              ).createShader(bounds),
              child: const Text(
                'Sportsense',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 3,
                  shadows: [
                    Shadow(
                      color: Color(0xFF7C4DFF),
                      offset: Offset(0, 0),
                      blurRadius: 30,
                    ),
                    Shadow(
                      color: Color(0xFF00D4FF),
                      offset: Offset(0, 0),
                      blurRadius: 50,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Подзаголовок
            Text(
              'AI-Powered Assistant',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: const Color(0xFFB39DDB),
                letterSpacing: 2,
                fontWeight: FontWeight.w300,
              ),
            ),

            const SizedBox(height: 16),

            // Чат
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: ChatInterface(
                    messages: _messages,
                    onSendMessage: _sendMessage,
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
