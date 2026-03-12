import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/qwen_api_service.dart';
import 'services/query_datetime_parser.dart';
import 'services/rankings_relevance_service.dart';
import 'services/rankings_vector_search.dart';
import 'services/uefa_parser.dart';
import 'services/uefa_rankings_api_service.dart';
import 'services/uefa_search_manager.dart';
import 'services/hf_embedding_service.dart';
import 'services/user_query_vectorizer.dart';
import 'services/vector_db_manager.dart';
import 'widgets/chat_interface.dart';
import 'widgets/space_background.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final vectorDbManager = VectorDatabaseManager();
  await vectorDbManager.initialize();

  final embeddingService = HfEmbeddingService();
  final embeddingAvailable = await embeddingService.isAvailable();
  print(
    embeddingAvailable
        ? 'Hugging Face embedding API available'
        : 'Hugging Face embedding API unavailable. Run python scripts/hf_embeddings_api.py',
  );

  final queryVectorizer = UserQueryVectorizerService(
    dbManager: vectorDbManager,
    embeddingService: embeddingService,
  );
  await queryVectorizer.initialize();

  final rankingsApi = UefaRankingsApiService();
  final rankingsApiAvailable = await rankingsApi.isAvailable();
  print(
    rankingsApiAvailable
        ? 'UEFA Rankings API available (Python + Playwright)'
        : 'UEFA Rankings API unavailable (run python scripts/uefa_parser_api.py)',
  );

  final uefaParser = UefaParser(
    vectorDbManager: vectorDbManager,
    rankingsApi: rankingsApi,
    embeddingService: embeddingService,
  );

  final rankingsSearch = RankingsVectorSearch(
    dbManager: vectorDbManager,
    embeddingService: embeddingService,
  );

  final qwenApi = QwenApiService();
  final qwenAvailable = await qwenApi.isAvailable();
  print(
    qwenAvailable
        ? 'Hugging Face Llama API available'
        : 'Hugging Face Llama API unavailable. Set HF_TOKEN in .env',
  );

  runApp(
    SpaceApp(
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
          'Здравствуйте! Я ваш ИИ-ассистент Sportsense. Чем я могу вам помочь сегодня?',
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

    if (!widget.rankingsApiAvailable) {
      _messages.add(
        ChatMessage(
          text:
              '⚠️ UEFA Rankings API недоступен.\nЗапустите:\n```\npython scripts/uefa_parser_api.py\n```\n\nПока данные не будут загружены.',
          isUser: false,
          textColor: Colors.orange,
        ),
      );
    }

    if (!widget.qwenAvailable) {
      _messages.add(
        ChatMessage(
          text:
              '⚠️ Hugging Face Llama API недоступен.\nУкажите `HF_TOKEN` в `.env`.\n\nПока используется тестовый режим.',
          isUser: false,
          textColor: Colors.orange,
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
    final hasUefaTrigger = await _uefaSearchManager.interceptQuery(text);

    if (hasUefaTrigger) {
      while (_uefaSearchManager.isSearching) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    final relevance = RankingsRelevanceService.checkRelevance(text);
    final textColor = RankingsRelevanceService.getRelevanceColor(relevance);
    final temporalContext = QueryDateTimeParser.parse(text);

    String? parsingStatus;
    String ragContext = '';
    await _queryVectorizer.vectorizeQuery(text);

    if (relevance >= 2.0) {
      parsingStatus = '🔄 RAG: парсинг UEFA Rankings...';
      print('RAG: relevant rankings query detected, starting parsing...');

      await _uefaParser.parseAndSaveRankings();
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (relevance >= 1.0) {
      print('RAG: searching vector database...');
      ragContext = await _rankingsSearch.getRagContext(text, limit: 10);

      if (ragContext.isEmpty) {
        print('RAG: no data found in vector database');
      } else {
        print('RAG: context received (${ragContext.length} chars)');
      }
    }

    String botResponse;
    if (widget.qwenAvailable) {
      print('RAG: sending request to Hugging Face with context...');

      final qwenResponse = await _qwenApi.chat(
        text,
        context: ragContext.isNotEmpty ? ragContext : null,
        temporalContext: temporalContext.toPromptContext(),
        maxTokens: 1024,
      );

      if (qwenResponse != null) {
        botResponse = qwenResponse.response;
        print('RAG: response received (${qwenResponse.tokensUsed} tokens)');
      } else {
        botResponse = 'Ошибка при получении ответа от Hugging Face Llama API.';
        print('RAG: failed to get Hugging Face response');
      }
    } else {
      botResponse =
          '🤖 **Тестовый режим** (Hugging Face Llama API недоступен)\n\n';

      if (ragContext.isNotEmpty) {
        botResponse += '📊 **Найдено в векторной базе:**\n';
        botResponse += '```\n$ragContext\n```\n\n';
      } else {
        botResponse += '⚠️ Данные в векторной базе не найдены.\n\n';
      }

      if (temporalContext.hasAnyTemporalReference) {
        botResponse += '🕒 **Распознанный временной контекст:**\n';
        botResponse += '```\n${temporalContext.toPromptContext()}\n```\n\n';
      }

      botResponse += '📝 **Ваш запрос:** "$text"\n';
      botResponse +=
          '🎯 **Релевантность:** ${RankingsRelevanceService.getRelevanceLabel(relevance)}\n\n';
      botResponse += '💡 **Для реальных ответов:**\n';
      botResponse += 'Укажите `HF_TOKEN` в `.env`.\n';
    }

    String fullResponse;
    if (parsingStatus != null && ragContext.isNotEmpty) {
      fullResponse = '$parsingStatus\n\n$botResponse';
    } else if (parsingStatus != null) {
      fullResponse = '$parsingStatus\n\n$botResponse';
    } else if (ragContext.isNotEmpty && widget.qwenAvailable) {
      fullResponse = '📊 **RAG: данные из векторной базы**\n\n$botResponse';
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
            const SizedBox(height: 16),
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
