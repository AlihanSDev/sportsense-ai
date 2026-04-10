import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// ======================= СЕРВИСЫ =======================
import 'services/theme_notifier.dart';
import 'services/uefa_search_manager.dart';
import 'services/vector_db_manager.dart';
import 'services/user_query_vectorizer.dart';
import 'services/rankings_relevance_service.dart';
import 'services/uefa_parser.dart';
import 'services/qwen_api_service.dart';
import 'services/huggingface_api_service.dart';
import 'services/rankings_vector_search.dart';
import 'services/uefa_rankings_api_service.dart';
import 'services/database_service.dart';
import 'services/database_models.dart';
import 'services/matches_service.dart';

// ======================= ВИДЖЕТЫ =======================
import 'widgets/space_background.dart';
import 'widgets/chat_interface.dart';
import 'widgets/auth_dialog.dart';

// ======================= КОНФИГУРАЦИЯ =======================
const String DEVICE_ID = 'small_phone_cold_boost';
const String DEVICE_NAME = 'Small Phone Cold Boost';
const String DEVICE_SCREEN = '720x1280';
const String DEVICE_RAM = '1024MB';
const String DEVICE_CPU = '4 cores x86_64';
const String ANDROID_API = '36.1';

const String QWEN_API_URL = 'http://127.0.0.1:5000';
const String UEFA_PARSER_API_URL = 'http://127.0.0.1:8000';
const String QDRANT_HOST = 'localhost';
const int QDRANT_PORT = 6333;

// ======================= THEME =======================
// ThemeNotifier и AppTheme импортированы из services/theme_notifier.dart

enum AppLanguage { ru, en }

class LanguageNotifier extends ChangeNotifier {
  AppLanguage _language = AppLanguage.ru;

  AppLanguage get language => _language;
  bool get isRussian => _language == AppLanguage.ru;

  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }
}

final languageNotifier = LanguageNotifier();

String tr(String ru, String en) =>
    languageNotifier.isRussian ? ru : en;

/// Получить цвет текста в зависимости от темы
Color onSurface(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white
        : const Color(0xFF1A1A2E);

Color onSurfaceSecondary(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.72)
        : const Color(0xFF6B7280);

Color surfaceContainer(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.04);

Color surfaceBorder(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withOpacity(0.12)
        : Colors.black.withOpacity(0.08);

// ======================= MODELS =======================
class ChatMessage {
  final String text;
  final bool isUser;
  final Color? textColor;
  final List<SearchSource> sources;
  ChatMessage({
    required this.text,
    required this.isUser,
    this.textColor,
    this.sources = const [],
  });
}

// ======================= MAIN =======================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Загрузка переменных окружения из .env
  try {
    await dotenv.load(fileName: '.env');
    print('[ENV] ✅ .env загружен');
  } catch (e) {
    print('[ENV] ⚠️ .env не найден, используются значения по умолчанию');
  }

  // Инициализация базы данных
  initDatabase();

  final appState = await _initializeAppState();
  if (appState == null) {
    _showEmergencyApp();
    return;
  }

  runApp(
    AnimatedBuilder(
      animation: Listenable.merge([themeNotifier, languageNotifier]),
      builder: (context, _) {
        return SpaceApp(
          vectorDbManager: appState['vectorDbManager'],
          queryVectorizer: appState['queryVectorizer'],
          uefaParser: appState['uefaParser'],
          qwenApi: appState['qwenApi'],
          hfApi: appState['hfApi'],
          rankingsSearch: appState['rankingsSearch'],
          rankingsApiAvailable: appState['rankingsApiAvailable'],
          qwenAvailable: appState['qwenAvailable'],
          hfAvailable: appState['hfAvailable'],
        );
      },
    ),
  );
}

// ======================= APP =======================
class SpaceApp extends StatelessWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final HuggingFaceApiService hfApi;
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;
  final bool hfAvailable;

  const SpaceApp({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.hfApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
    required this.hfAvailable,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sportsense',
      debugShowCheckedModeBanner: false,
      themeMode: themeNotifier.mode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.light,
          background: const Color(0xFFF8F9FA),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ).copyWith(scaffoldBackgroundColor: Colors.white),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4A90E2),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
      ),
      home: HomeScreen(
        vectorDbManager: vectorDbManager,
        queryVectorizer: queryVectorizer,
        uefaParser: uefaParser,
        qwenApi: qwenApi,
        hfApi: hfApi,
        rankingsSearch: rankingsSearch,
        rankingsApiAvailable: rankingsApiAvailable,
        qwenAvailable: qwenAvailable,
        hfAvailable: hfAvailable,
      ),
    );
  }
}

// ======================= HOME SCREEN =======================
class HomeScreen extends StatelessWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final HuggingFaceApiService hfApi;
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;
  final bool hfAvailable;

  const HomeScreen({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.hfApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
    required this.hfAvailable,
  });

  void _openAssistant(BuildContext context, {String? draft}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          vectorDbManager: vectorDbManager,
          queryVectorizer: queryVectorizer,
          uefaParser: uefaParser,
          qwenApi: qwenApi,
          hfApi: hfApi,
          rankingsSearch: rankingsSearch,
          rankingsApiAvailable: rankingsApiAvailable,
          qwenAvailable: qwenAvailable,
          hfAvailable: hfAvailable,
          initialDraft: draft,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _HomeScreenShell(
      rankingsApiAvailable: rankingsApiAvailable,
      qwenAvailable: qwenAvailable,
      onOpenAssistant: ({String? draft}) =>
          _openAssistant(context, draft: draft),
    );
  }
}

class _HomeScreenShell extends StatefulWidget {
  final bool rankingsApiAvailable;
  final bool qwenAvailable;
  final void Function({String? draft}) onOpenAssistant;

  const _HomeScreenShell({
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
    required this.onOpenAssistant,
  });

  @override
  State<_HomeScreenShell> createState() => _HomeScreenShellState();
}

class _HomeScreenShellState extends State<_HomeScreenShell> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final statusItems = [
      _StatusItem(
        label: tr('Рейтинги UEFA', 'UEFA rankings'),
        value: widget.rankingsApiAvailable
            ? tr('онлайн', 'online')
            : tr('офлайн', 'offline'),
        active: widget.rankingsApiAvailable,
      ),
      _StatusItem(
        label: tr('AI-анализ', 'AI analysis'),
        value: widget.qwenAvailable ? tr('готов', 'ready') : tr('ожидание', 'standby'),
        active: widget.qwenAvailable,
      ),
      _StatusItem(label: tr('Режим', 'Mode'), value: tr('матчдэй', 'matchday'), active: true),
    ];

    final navItems = [
      _NavItem(label: tr('Главная', 'Home'), icon: Icons.home_rounded),
      _NavItem(label: tr('Матчи', 'Matches'), icon: Icons.sports_soccer_rounded),
      _NavItem(label: tr('Турниры', 'Tournaments'), icon: Icons.emoji_events_rounded),
      _NavItem(label: tr('Сохраненное', 'Saved'), icon: Icons.bookmark_rounded),
    ];

    return Scaffold(
      extendBody: true,
      body: SpaceBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 128),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                const SizedBox(height: 24),
                _buildHero(statusItems),
                const SizedBox(height: 24),
                _buildTabContent(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: _BottomDock(
        items: navItems,
        selectedIndex: _selectedTab,
        onSelect: (index) => setState(() => _selectedTab = index),
        onOpenChat: () => widget.onOpenAssistant(),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitles = [
      tr('Ваш футбольный центр управления.', 'Your football command center.'),
      tr('Живой матчдэй с быстрым контекстом.', 'Live matchday view with quick context.'),
      tr('Турниры, интриги и движение по сетке.', 'Competitions, race tables and storylines.'),
      tr('Сохранённые клубы, игроки и быстрые сводки.', 'Saved clubs, players and briefing shortcuts.'),
    ];

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sportsense',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  color: onSurface(context),
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitles[_selectedTab],
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: onSurfaceSecondary(context),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        const _LanguageToggle(),
        const SizedBox(width: 10),
        Container(
          decoration: BoxDecoration(
            color: surfaceContainer(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: surfaceBorder(context)),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: Icon(Icons.tune_rounded, color: onSurface(context)),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(List<_StatusItem> statusItems) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final eyebrow = [
      tr('MATCHDAY HUB', 'MATCHDAY HUB'),
      tr('LIVE BOARD', 'LIVE BOARD'),
      tr('TOURNAMENT DESK', 'TOURNAMENT DESK'),
      tr('WATCHLIST', 'WATCHLIST'),
    ];
    final titles = [
      tr(
        'Начинайте со спортивных сценариев, а не с пустого чата.',
        'Start from football scenarios, not from an empty bot conversation.',
      ),
      tr(
        'Следите за вечером как в матчдэй-приложении и переходите к аналитике по необходимости.',
        'Follow the evening like a matchday app, with quick pivots into deeper analysis.',
      ),
      tr(
        'Просматривайте турнирные сюжеты, а не подсказки для ассистента.',
        'Browse tournament stories, not assistant prompts.',
      ),
      tr(
        'Держите свой футбольный watchlist в одном тапе.',
        'Keep your football watchlist one tap away.',
      ),
    ];
    final descriptions = [
      tr(
        'Изучайте рейтинги, сравнивайте команды и открывайте AI-анализ только тогда, когда он реально нужен.',
        'Explore rankings, compare teams and open AI analysis only when it helps the flow.',
      ),
      tr(
        'Смотрите актуальные матчи, сигналы формы и открывайте предматчевые разборы по нужной игре.',
        'See featured fixtures, momentum cues and open tailored previews for any matchup.',
      ),
      tr(
        'Переходите между турнирами и ключевыми движениями без необходимости начинать с чата.',
        'Move through competition hubs, qualification races and club movement without entering chat first.',
      ),
      tr(
        'Возвращайтесь к сохранённым клубам, игрокам и часто используемым сценариям.',
        'Return to saved teams, player briefs and your most-used briefing shortcuts.',
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: isDark
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF102A43), Color(0xFF1E5F74), Color(0xFF3BA99C)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF4A90E2), Color(0xFF357ABD), Color(0xFF3BA99C)],
              ),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3BA99C).withOpacity(isDark ? 0.18 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              eyebrow[_selectedTab],
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            titles[_selectedTab],
            style: GoogleFonts.spaceGrotesk(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            descriptions[_selectedTab],
            style: GoogleFonts.inter(
              fontSize: 15,
              color: Colors.white.withOpacity(0.82),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PrimaryButton(
                label: _selectedTab == 1
                    ? tr('Открыть превью матча', 'Open Match Preview')
                    : _selectedTab == 2
                        ? tr('Открыть турнирную сводку', 'Open Tournament Brief')
                        : _selectedTab == 3
                            ? tr('Открыть сохранённую сводку', 'Open Saved Briefing')
                            : tr('Открыть центр анализа', 'Open Analysis Center'),
                icon: Icons.north_east_rounded,
                onTap: () => widget.onOpenAssistant(
                  draft: _selectedTab == 1
                      ? 'Подготовь краткий предматчевый разбор двух команд'
                      : _selectedTab == 2
                          ? 'Дай турнирную сводку и ключевые движения клубов'
                          : _selectedTab == 3
                              ? 'Сделай короткую сводку по сохраненным клубам и игрокам'
                              : null,
                ),
              ),
              _GhostButton(
                label: tr('Сводка UEFA', 'UEFA Snapshot'),
                icon: Icons.insights_rounded,
                onTap: () => widget.onOpenAssistant(
                  draft:
                      'Дай краткую сводку по текущему состоянию рейтингов UEFA',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: statusItems.map((item) => _StatusPill(item: item)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent() {
    switch (_selectedTab) {
      case 1:
        return _MatchesTabLive(onOpenAssistant: widget.onOpenAssistant);
      case 2:
        return _TournamentsTab(onOpenAssistant: widget.onOpenAssistant);
      case 3:
        return _SavedTab(onOpenAssistant: widget.onOpenAssistant);
      default:
        return _OverviewTab(onOpenAssistant: widget.onOpenAssistant);
    }
  }
}

// ======================= CHAT SCREEN =======================
class ChatScreen extends StatefulWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final HuggingFaceApiService hfApi;
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;
  final bool hfAvailable;
  final String? initialDraft;

  const ChatScreen({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.hfApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
    required this.hfAvailable,
    this.initialDraft,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final UefaSearchManager _uefaSearchManager;
  final TextEditingController _controller = TextEditingController();
  final DatabaseService _db = DatabaseService();

  final List<ChatSession> _chats = [];
  int _currentChatIndex = 0;
  bool _isLoggedIn = false;
  User? _currentUser;
  String _username = '';
  bool _isInitializing = true;  // Флаг инициализации
  bool _isGenerating = false;   // Флаг генерации ответа
  bool _stopRequested = false;  // Флаг остановки
  bool _useSearch = false;      // Флаг поиска в интернете

  ChatSession? get _currentChatOrNull => _chats.isNotEmpty ? _chats[_currentChatIndex] : null;
  ChatSession get currentChat => _chats.isNotEmpty ? _chats[_currentChatIndex] : ChatSession(id: '0', title: '', messages: []);

  @override
  void initState() {
    super.initState();
    _uefaSearchManager = UefaSearchManager();
    _uefaSearchManager.initialize();
    _uefaSearchManager.addListener(_onUefaSearchChanged);
    
    // Запускаем инициализацию и создаём чат сразу
    _createNewChat();
    _checkAuth();  // Асинхронная проверка, не блокирует
  }

  /// Проверка авторизации при запуске
  Future<void> _checkAuth() async {
    try {
      final user = await _db.getCurrentUser();
      if (user != null) {
        if (!mounted) return;
        setState(() {
          _currentUser = user;
          _isLoggedIn = true;
          _username = user.name;
        });

        // Загружаем чаты пользователя
        await _loadUserChats();
      }
    } catch (e) {
      print('Ошибка проверки авторизации: $e');
    } finally {
      // В любом случае снимаем флаг инициализации
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }

    // Добавляем приветственное сообщение только если чат существует и пуст
    if (mounted && _chats.isNotEmpty) {
      final chat = _chats[_currentChatIndex];
      if (chat.messages.isEmpty) {
        chat.messages.add(
          ChatMessage(
            text: tr(
              'Здравствуйте! Я ваш ассистент Sportsense. Чем я могу вам помочь сегодня?',
              'Hello! I am your Sportsense assistant. How can I help you today?',
            ),
            isUser: false,
          ),
        );

        if (!widget.rankingsApiAvailable) {
          chat.messages.add(
            ChatMessage(
              text: '⚠️ UEFA Rankings API недоступен.\nЗапустите: python scripts/uefa_parser_api.py',
              isUser: false,
              textColor: const Color(0xFFB37B7B),
            ),
          );
        }

        if (!widget.qwenAvailable) {
          chat.messages.add(
            ChatMessage(
              text: '⚠️ Qwen API недоступен.\nЗапустите: python scripts/qwen_api.py',
              isUser: false,
              textColor: const Color(0xFFB37B7B),
            ),
          );
        }
      }
    }

    // Подставляем initialDraft если есть
    if (widget.initialDraft != null && widget.initialDraft!.trim().isNotEmpty) {
      _controller.text = widget.initialDraft!;
    }
  }

  /// Загрузка чатов пользователя из SQLite
  Future<void> _loadUserChats() async {
    if (_currentUser == null) return;

    try {
      final chats = await _db.getUserChats(_currentUser!.id!);
      if (chats.isNotEmpty && mounted) {
        setState(() {
          _chats.clear();
          for (final chat in chats) {
            _chats.add(ChatSession(
              id: chat.id.toString(),
              title: chat.title,
              messages: [],
            ));
          }
          _currentChatIndex = 0;
        });

        // Загружаем сообщения текущего чата
        await _loadChatMessages(_chats.first);
      } else if (mounted) {
        _createNewChat();
      }
    } catch (e) {
      print('Ошибка загрузки чатов: $e');
      if (mounted && _chats.isEmpty) {
        _createNewChat();
      }
    }
  }

  /// Загрузка сообщений чата из SQLite
  Future<void> _loadChatMessages(ChatSession chat) async {
    final chatId = int.tryParse(chat.id ?? '0');
    if (chatId == null) return;

    try {
      final messages = await _db.getChatMessages(chatId);
      if (messages.isNotEmpty && mounted) {
        setState(() {
          chat.messages.clear();
          for (final msg in messages) {
            chat.messages.add(ChatMessage(
              text: msg.text,
              isUser: msg.isUser,
            ));
          }
        });
      }
    } catch (e) {
      print('Ошибка загрузки сообщений: $e');
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

  void _createNewChat() {
    final newChat = ChatSession(
      id: DateTime.now().toString(),
      title: 'Чат ${_chats.length + 1}',
      messages: [],
    );

    // Если пользователь авторизован, сохраняем чат в SQLite
    if (_isLoggedIn && _currentUser != null) {
      _db.createChat(
        userId: _currentUser!.id!,
        title: newChat.title,
      ).then((savedChat) {
        if (savedChat != null && mounted) {
          setState(() {
            newChat.id = savedChat.id.toString();
          });
        }
      }).catchError((e) {
        print('Ошибка сохранения чата: $e');
      });
    }

    setState(() {
      _chats.add(newChat);
      _currentChatIndex = _chats.length - 1;
    });
  }

  void _switchChat(int index) {
    setState(() {
      _currentChatIndex = index;
    });
    Navigator.pop(context);
    _loadChatMessages(_chats[index]);
  }

  /// Показ диалога авторизации в новом стиле
  void _showRegistrationDialog() {
    showDialog<User>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AuthDialog(
          onAuthSuccess: (User user) async {
            setState(() {
              _currentUser = user;
              _isLoggedIn = true;
              _username = user.name;
            });
            await _loadUserChats();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Добро пожаловать, ${user.name}!'),
                backgroundColor: const Color(0xFF7C4DFF),
              ),
            );
          },
        );
      },
    ).then((user) {
      if (user != null && mounted) {
        setState(() {
          _currentUser = user;
          _isLoggedIn = true;
          _username = user.name;
        });
      }
    });
  }

  void _logout() {
    setState(() {
      _isLoggedIn = false;
      _username = '';
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Вы вышли из аккаунта')));
  }

  Drawer _buildDrawer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Drawer(
      backgroundColor: isDark ? Colors.black : Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.blue[50],
            ),
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.sports_soccer,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _isLoggedIn ? _username : tr('Гость', 'Guest'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isLoggedIn
                      ? tr('Аккаунт активен', 'Account active')
                      : tr('Не авторизован', 'Not signed in'),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.chat,
              color: isDark ? Colors.white : Colors.black,
            ),
            title: Text(
              tr('Чаты', 'Chats'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: () {},
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _chats.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(
                    _chats[index].title,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  selected: index == _currentChatIndex,
                  selectedTileColor: Colors.blue.withOpacity(0.1),
                  onTap: () => _switchChat(index),
                );
              },
            ),
          ),
          ListTile(
            leading: Icon(
              Icons.add_circle,
              color: isDark ? Colors.white : Colors.black,
            ),
            title: Text(
              tr('Новый чат', 'New chat'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: _createNewChat,
          ),
          const Divider(),
          if (!_isLoggedIn)
            ListTile(
              leading: const Icon(Icons.app_registration, color: Colors.blue),
              title: Text(
                tr('Регистрация / Вход', 'Sign up / Sign in'),
                style: const TextStyle(color: Colors.blue),
              ),
              onTap: _showRegistrationDialog,
            ),
          if (_isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                tr('Выйти', 'Sign out'),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: _logout,
            ),
          ListTile(
            leading: Icon(
              Icons.settings,
              color: isDark ? Colors.white : Colors.black,
            ),
            title: Text(
              tr('Настройки', 'Settings'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage(String text) async {
    if (text.isEmpty || _chats.isEmpty) return;

    // Если уже генерируем — останавливаем
    if (_isGenerating) {
      setState(() {
        _stopRequested = true;
      });
      return;
    }

    // Специальные команды (только UI)
    if (text == 'COMMAND-HEY') {
      setState(() {
        currentChat.messages.add(ChatMessage(text: text, isUser: true));
      });
      await Future.delayed(const Duration(milliseconds: 300));
      final info = '''
*Список доступных команд:*
- TEXT-IDLE: демонстрация длительной печати (~25 секунд)
- BANANA-HEY: банановый отклик
- COMMAND-HEY: показать это сообщение
''';
      if (mounted) {
        setState(() {
          currentChat.messages.add(ChatMessage(
              text: info, isUser: false, textColor: const Color(0xFF7C4DFF)));
        });
      }
      return;
    }

    if (text == 'BANANA-HEY') {
      setState(() {
        currentChat.messages.add(ChatMessage(text: text, isUser: true));
      });
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() {
          currentChat.messages.add(ChatMessage(
              text: '🍌 БАНАН! 🍌', isUser: false, textColor: const Color(0xFFFFD700)));
        });
      }
      return;
    }

    if (text == 'TEXT-IDLE') {
      setState(() {
        currentChat.messages.add(ChatMessage(text: text, isUser: true));
      });
      await Future.delayed(const Duration(seconds: 3));
      final reply = 'Это пример генерируемого текста. Он появляется постепенно, словно AI печатает его прямо сейчас.';
      if (mounted) {
        setState(() {
          currentChat.messages.add(ChatMessage(
              text: reply, isUser: false, textColor: const Color(0xFF7C4DFF)));
        });
      }
      return;
    }

    // Сохраняем сообщение пользователя в SQLite
    if (_isLoggedIn && _currentUser != null && currentChat.id != null && currentChat.id != '0') {
      final chatId = int.parse(currentChat.id!);
      _db.addMessage(
        chatId: chatId,
        text: text,
        isUser: true,
      ).catchError((e) {
        print('Ошибка сохранения сообщения: $e');
        return null;
      });
    }

    setState(() {
      currentChat.messages.add(ChatMessage(text: text, isUser: true));
      _isGenerating = true;
      _stopRequested = false;
    });

    // Очищаем поле ввода сразу, не ждём ответа
    _controller.clear();

    final relevance = RankingsRelevanceService.checkRelevance(text);
    final textColor = RankingsRelevanceService.getRelevanceColor(relevance);

    // Автоопределение поиска по триггерным словам
    final searchTriggers = [
      'найди в интернете', 'найди в сети', 'поищи в интернете', 'поищи в сети',
      'search the internet', 'search the web', 'find online', 'look up',
      'найди онлайн', 'погугли', 'google it', 'search online',
    ];
    final shouldSearch = _useSearch || searchTriggers.any((t) => text.toLowerCase().contains(t));
    print('🔍 Web search: shouldSearch=$shouldSearch (button=$_useSearch, triggers matched)');

    String ragContext = '';

    if (_stopRequested) { _cancelGeneration(); return; }

    if (relevance >= 2.0) {
      await widget.uefaParser.parseAndSaveRankings();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_stopRequested) { _cancelGeneration(); return; }

    if (relevance >= 1.0) {
      ragContext = await widget.rankingsSearch.getRagContext(text, limit: 10);
    }

    if (_stopRequested) { _cancelGeneration(); return; }

    // Добавляем пустое сообщение бота, которое будем заполнять
    final botMsgIndex = currentChat.messages.length;
    if (mounted) {
      setState(() {
        currentChat.messages.add(ChatMessage(
          text: '',
          isUser: false,
          textColor: textColor,
        ));
      });
    }

    String botResponse;
    List<SearchSource> botSources = [];

    // Приоритет: HuggingFace (Mistral 7B) > локальная Qwen > заглушка
    if (widget.hfAvailable && shouldSearch) {
      // HuggingFace с поиском — передаём webContext
      String? webContext;
      if (shouldSearch) {
        // Триггерные слова для поиска — используем тот же запрос
        webContext = await _fetchWebContext(text);
      }
      final hfResponse = await widget.hfApi.chat(
        text,
        maxTokens: 1024,
        temperature: 0.7,
        context: ragContext.isNotEmpty ? ragContext : null,
        useSearch: shouldSearch,
        webContext: webContext,
      );
      if (_stopRequested) { _cancelGeneration(); return; }
      botResponse = hfResponse?.response ?? 'Произошла ошибка при обработке запроса. Попробуйте ещё раз.';
      print('[HF] Ответ: ${botResponse.substring(0, botResponse.length.clamp(0, 100))}...');
    } else if (widget.qwenAvailable) {
      final qwenResponse = await widget.qwenApi.chat(
        text,
        context: ragContext.isNotEmpty ? ragContext : null,
        maxTokens: 1024,
        useSearch: shouldSearch,
      );
      if (_stopRequested) { _cancelGeneration(); return; }
      botResponse = qwenResponse?.response ?? 'Произошла ошибка при обработке запроса. Попробуйте ещё раз.';
      botSources = qwenResponse?.sources ?? [];
    } else {
      // Имитация постепенной генерации
      botResponse = 'Спасибо за вопрос! В данный момент я готовлю ответ по вашему запросу: "$text"';
      if (ragContext.isNotEmpty) botResponse += '\n\n$ragContext';

      // Анимация посимвольного появления
      for (int i = 1; i <= botResponse.length; i++) {
        if (_stopRequested) { _cancelGeneration(); return; }
        if (mounted) {
          setState(() {
            currentChat.messages[botMsgIndex] = ChatMessage(
              text: botResponse.substring(0, i),
              isUser: false,
              textColor: textColor,
            );
          });
        }
        await Future.delayed(const Duration(milliseconds: 15));
      }
      setState(() { _isGenerating = false; });
      return;
    }

    if (_stopRequested) { _cancelGeneration(); return; }

    // Анимация посимвольного появления ответа LLM
    for (int i = 1; i <= botResponse.length; i++) {
      if (_stopRequested) { _cancelGeneration(); return; }
      if (mounted) {
        setState(() {
          currentChat.messages[botMsgIndex] = ChatMessage(
            text: botResponse.substring(0, i),
            isUser: false,
            textColor: textColor,
            sources: botSources,
          );
        });
      }
      await Future.delayed(const Duration(milliseconds: 12));
    }

    // Сохраняем ответ бота в SQLite
    if (_isLoggedIn && _currentUser != null && currentChat.id != null && currentChat.id != '0') {
      final chatId = int.parse(currentChat.id!);
      _db.addMessage(
        chatId: chatId,
        text: botResponse,
        isUser: false,
      ).catchError((e) {
        print('Ошибка сохранения ответа: $e');
        return null;
      });
    }

    setState(() { _isGenerating = false; });
  }

  void _cancelGeneration() {
    if (currentChat.messages.isNotEmpty) {
      final lastMsg = currentChat.messages.last;
      if (!lastMsg.isUser && lastMsg.text.isEmpty) {
        // Удаляем пустое сообщение-заполнитель
        currentChat.messages.removeLast();
      }
    }
    setState(() {
      _isGenerating = false;
      _stopRequested = false;
    });
  }

  /// Получает контекст из интернета через Python API сервер (/search endpoint)
  Future<String?> _fetchWebContext(String query) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:5000/search'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'query': query}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final ctx = data['web_context'] as String?;
        if (ctx != null && ctx.isNotEmpty) {
          print('🔍 Web context получен: ${ctx.length} символов');
        }
        return ctx;
      }
    } catch (e) {
      print('⚠️ Ошибка получения web контекста: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;

    // Показываем индикатор загрузки во время инициализации
    if (_isInitializing && _chats.isEmpty) {
      return SpaceBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                'Загрузка Sportsense...',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      drawer: _buildDrawer(),
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  // Стрелка назад
                  IconButton(
                    icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu_rounded, color: isDark ? Colors.white : const Color(0xFF1A1A2E)),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  const _LanguageToggle(),
                ],
              ),
              const SizedBox(height: 6),
              // Заголовок
              Text(
                tr('Центр анализа', 'Analysis Center'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  letterSpacing: -0.6,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF0F766E), Color(0xFF14B8A6)]),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tr('АНАЛИТИКА ПО ЗАПРОСУ', 'ON-DEMAND ANALYSIS'),
                  style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white, letterSpacing: 1.2),
                ),
              ),
              const SizedBox(height: 12),
              // Чипсы
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PromptChip(
                        label: tr('Сводка UEFA', 'UEFA snapshot'),
                        onTap: () => _controller.text = 'Дай краткую сводку по текущему состоянию рейтингов UEFA',
                      ),
                      _PromptChip(
                        label: tr('Сравнить клубы', 'Compare clubs'),
                        onTap: () => _controller.text = 'Сравни две команды по форме и силе в рейтинге UEFA',
                      ),
                      _PromptChip(
                        label: tr('Профиль игрока', 'Player brief'),
                        onTap: () => _controller.text = 'Подготовь короткий аналитический профиль игрока',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Сообщения
              Expanded(
                child: _chats.isEmpty
                    ? const Center(child: Text('Загрузка чата...', style: TextStyle(color: Colors.white54)))
                    : ListView.builder(
                        controller: ScrollController(),
                        itemCount: currentChat.messages.length,
                        itemBuilder: (context, index) {
                          final msg = currentChat.messages[index];
                          // Показываем индикатор поиска вместо typing когда включён поиск
                          if (msg.text.isEmpty && !msg.isUser) {
                            return _useSearch ? const _SearchIndicator() : const _TypingIndicator();
                          }
                          return _MessageBubble(msg: msg);
                        },
                      ),
              ),
              // Поле ввода
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // Индикатор активного поиска
                    if (_useSearch)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.public_rounded, size: 14, color: Color(0xFF4A90E2)),
                            const SizedBox(width: 6),
                            Text(
                              tr('Поиск в интернете включён', 'Web search enabled'),
                              style: const TextStyle(fontSize: 11, color: Color(0xFF4A90E2)),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        // Кнопка браузера для включения поиска
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 6),
                          decoration: BoxDecoration(
                            color: _useSearch
                                ? const Color(0xFF4A90E2).withOpacity(0.2)
                                : Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _useSearch
                                  ? const Color(0xFF4A90E2).withOpacity(0.4)
                                  : Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: IconButton(
                            icon: Icon(
                              Icons.public_rounded,
                              color: _useSearch ? const Color(0xFF4A90E2) : Colors.white54,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _useSearch = !_useSearch;
                              });
                            },
                            tooltip: tr('Поиск в интернете', 'Web search'),
                          ),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            enabled: !_isGenerating,
                            decoration: InputDecoration(
                              hintText: _isGenerating
                                  ? tr('ИИ генерирует ответ...', 'AI is generating...')
                                  : tr('Введите запрос для аналитики', 'Enter an analysis request'),
                              hintStyle: TextStyle(
                                color: _isGenerating ? Colors.white.withOpacity(0.3) : Colors.white54,
                              ),
                            ),
                            style: const TextStyle(color: Colors.white),
                            onSubmitted: (_) => _sendMessage(_controller.text),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: _isGenerating
                              ? IconButton(
                                  key: const ValueKey('stop'),
                                  icon: const Icon(Icons.stop_rounded, color: Color(0xFFEF5350)),
                                  onPressed: () => _sendMessage(''),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFFEF5350).withOpacity(0.15),
                                    shape: const CircleBorder(),
                                  ),
                                )
                              : IconButton(
                                  key: const ValueKey('send'),
                                  icon: const Icon(Icons.send_rounded, color: Colors.white),
                                  onPressed: () => _sendMessage(_controller.text),
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      // Нижняя панель навигации
      extendBody: true,
      bottomNavigationBar: _ChatBottomDock(),
    );
  }
}

/// Нижняя панель навигации для экрана чата (без круглой кнопки — мы уже в чате)
class _ChatBottomDock extends StatelessWidget {
  const _ChatBottomDock();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isDark = themeNotifier.isDark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.4) : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                _ChatNavItem(
                  icon: Icons.home_rounded,
                  label: tr('Главная', 'Home'),
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
                _ChatNavItem(
                  icon: Icons.sports_soccer_rounded,
                  label: tr('Матчи', 'Matches'),
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
                _ChatNavItem(
                  icon: Icons.emoji_events_rounded,
                  label: tr('Турниры', 'Tournaments'),
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
                _ChatNavItem(
                  icon: Icons.bookmark_rounded,
                  label: tr('Сохранённое', 'Saved'),
                  onTap: () => Navigator.pop(context),
                  isDark: isDark,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage msg;
  const _MessageBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: msg.isUser ? Colors.blue : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(msg.text, style: TextStyle(color: msg.textColor ?? Colors.white)),
            if (msg.sources.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.link_rounded, size: 14, color: Color(0xFF4A90E2)),
                  const SizedBox(width: 4),
                  Text(
                    tr('Источники', 'Sources'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF4A90E2)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ...msg.sources.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () {
                    // TODO: open URL
                    print('Source URL: ${s.url}');
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: const TextStyle(color: Color(0xFF4A90E2), fontSize: 12),
                      ),
                      Expanded(
                        child: Text(
                          s.title.isNotEmpty ? s.title : s.url,
                          style: const TextStyle(
                            color: Color(0xFF4A90E2),
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ],
        ),
      ),
    );
  }
}

/// Анимированный индикатор "печатает..."
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      );
      c.repeat(reverse: true);
      c.forward();
      // Задержка для каждой точки
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) c.forward();
      });
      return c;
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _animations[i],
              builder: (context, _) {
                return Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(_animations[i].value * 0.6),
                    shape: BoxShape.circle,
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }
}

/// Анимированный индикатор поиска в интернете
class _SearchIndicator extends StatefulWidget {
  const _SearchIndicator();

  @override
  State<_SearchIndicator> createState() => _SearchIndicatorState();
}

class _SearchIndicatorState extends State<_SearchIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _rotation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.all(8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF4A90E2).withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF4A90E2).withOpacity(0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _rotation,
              builder: (context, _) {
                return Transform.rotate(
                  angle: _rotation.value * 2 * 3.14159,
                  child: const Icon(
                    Icons.public_rounded,
                    color: Color(0xFF4A90E2),
                    size: 18,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Text(
              tr('Ищу в интернете...', 'Searching the web...'),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF4A90E2),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            _SearchDots(),
          ],
        ),
      ),
    );
  }
}

/// Три анимированные точки для поиска
class _SearchDots extends StatefulWidget {
  const _SearchDots();

  @override
  State<_SearchDots> createState() => _SearchDotsState();
}

class _SearchDotsState extends State<_SearchDots> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      final c = AnimationController(
        duration: const Duration(milliseconds: 500),
        vsync: this,
      );
      c.repeat(reverse: true);
      Future.delayed(Duration(milliseconds: i * 160), () {
        if (mounted) c.forward();
      });
      return c;
    });
    _animations = _controllers.map((c) {
      return Tween<double>(begin: 0.2, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _animations[i],
          builder: (context, _) {
            return Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFF4A90E2).withOpacity(_animations[i].value * 0.7),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}

class _ChatNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  const _ChatNavItem({required this.icon, required this.label, required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isDark ? Colors.white.withOpacity(0.55) : Colors.black38, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

// ======================= SETTINGS =======================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Настройки', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr('Тема оформления', 'Appearance'),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: themeNotifier,
            builder: (context, _) {
              return Column(
                children: [
                  _ThemeCard(
                    theme: AppTheme.dark,
                    current: themeNotifier.theme,
                    title: tr('Тёмная', 'Dark'),
                    subtitle: tr('Классический космос со звёздами', 'Classic space with stars'),
                    gradient: const [Color(0xFF0B0B12), Color(0xFF1A1A26)],
                    accent: const Color(0xFF8B7DD8),
                    onTap: () => themeNotifier.setTheme(AppTheme.dark),
                  ),
                  const SizedBox(height: 12),
                  _ThemeCard(
                    theme: AppTheme.sportsense,
                    current: themeNotifier.theme,
                    title: 'Sportsense',
                    subtitle: tr('Тёмный с геометрическими деталями', 'Dark with geometric details'),
                    gradient: const [Color(0xFF0B0B12), Color(0xFF14141F)],
                    accent: const Color(0xFFA7C7FF),
                    showHoneycomb: true,
                    onTap: () => themeNotifier.setTheme(AppTheme.sportsense),
                  ),
                  const SizedBox(height: 12),
                  _ThemeCard(
                    theme: AppTheme.light,
                    current: themeNotifier.theme,
                    title: tr('Светлая', 'Light'),
                    subtitle: tr('Молочный фон с голубыми сотами', 'Milk-white with blue honeycombs'),
                    gradient: const [Color(0xFFF8F9FA), Color(0xFFD6E6FF)],
                    accent: const Color(0xFF4A90E2),
                    onTap: () => themeNotifier.setTheme(AppTheme.light),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(tr('О приложении', 'About')),
            subtitle: Text(tr('Версия 1.0.0', 'Version 1.0.0')),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Sportsense',
                applicationVersion: '1.0.0',
                applicationLegalese: '© 2026 Sportsense. Все права защищены.',
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final AppTheme theme;
  final AppTheme current;
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color accent;
  final bool showHoneycomb;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.theme,
    required this.current,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accent,
    this.showHoneycomb = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = theme == current;
    final isDarkTheme = theme != AppTheme.light;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: isSelected ? 2.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isSelected ? 0.3 : 0.08),
              blurRadius: isSelected ? 16 : 8,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Row(
          children: [
            // Превью темы
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                border: Border.all(
                  color: isDarkTheme
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.06),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Мини-звёзды для тёмных тем
                    if (isDarkTheme)
                      ...List.generate(8, (i) {
                        final rng = (i * 137.5) % 1;
                        return Positioned(
                          left: rng * 44 + 4,
                          top: ((i * 97.3) % 1) * 44 + 4,
                          child: Container(
                            width: 1.5,
                            height: 1.5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.4 + (i % 3) * 0.2),
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }),
                    // Мини-соты для Sportsense/светлой
                    if (showHoneycomb || !isDarkTheme)
                      Center(
                        child: CustomPaint(
                          size: const Size(30, 30),
                          painter: _MiniHoneycomb(color: accent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Текст
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDarkTheme ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: isDarkTheme
                          ? Colors.white.withOpacity(0.6)
                          : const Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            // Галочка
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? accent : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accent : (isDarkTheme ? Colors.white30 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniHoneycomb extends CustomPainter {
  final Color color;
  _MiniHoneycomb({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color.withOpacity(0.5);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = 8.0;

    for (int ring = 0; ring < 2; ring++) {
      final r = radius * (ring + 1);
      for (int i = 0; i < 6; i++) {
        final angle = math.pi / 3 * i;
        final cx = center.dx + r * 0.6 * math.cos(angle);
        final cy = center.dy + r * 0.6 * math.sin(angle);

        final path = Path();
        for (int j = 0; j < 6; j++) {
          final a = math.pi / 3 * j;
          final hx = cx + 5 * math.cos(a);
          final hy = cy + 5 * math.sin(a);
          if (j == 0) {
            path.moveTo(hx, hy);
          } else {
            path.lineTo(hx, hy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniHoneycomb oldDelegate) => false;
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF102A43),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: const Color(0xFF102A43)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _GhostButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusItem {
  final String label;
  final String value;
  final bool active;

  const _StatusItem({
    required this.label,
    required this.value,
    required this.active,
  });
}

class _StatusPill extends StatelessWidget {
  final _StatusItem item;

  const _StatusPill({required this.item});

  @override
  Widget build(BuildContext context) {
    final accent =
        item.active ? const Color(0xFF34D399) : const Color(0xFFF97316);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '${item.label} ',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.66),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: item.value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionData {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _QuickActionData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickActionData action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(28),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                action.colors.first.withOpacity(0.92),
                action.colors.last.withOpacity(0.86),
              ],
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(action.icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      action.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.45,
                        color: Colors.white.withOpacity(0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_rounded,
                color: Colors.white,
                size: 26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InsightCardData {
  final String eyebrow;
  final String title;
  final String description;

  const _InsightCardData({
    required this.eyebrow,
    required this.title,
    required this.description,
  });
}

class _InsightCard extends StatelessWidget {
  final _InsightCardData card;

  const _InsightCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.16),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.eyebrow.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7DD3FC),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            card.title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            card.description,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withOpacity(0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PromptChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ActionChip(
        onPressed: onTap,
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
        backgroundColor: Colors.white.withOpacity(0.08),
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([languageNotifier, themeNotifier]),
      builder: (context, _) {
        final isDark = themeNotifier.isDark;
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.black.withOpacity(0.1),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageButton(
                label: 'RU',
                selected: languageNotifier.language == AppLanguage.ru,
                onTap: () => languageNotifier.setLanguage(AppLanguage.ru),
              ),
              _LanguageButton(
                label: 'EN',
                selected: languageNotifier.language == AppLanguage.en,
                onTap: () => languageNotifier.setLanguage(AppLanguage.en),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LanguageButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = themeNotifier.isDark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? Colors.white : const Color(0xFF4A90E2))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? (isDark ? const Color(0xFF102A43) : Colors.white)
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;

  const _NavItem({required this.label, required this.icon});
}

class _BottomDock extends StatelessWidget {
  final List<_NavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenChat;

  const _BottomDock({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
    required this.onOpenChat,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeNotifier,
      builder: (context, _) {
        final isDark = themeNotifier.isDark;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
              ),
            ),
            child: Row(
              children: [
                // Главная
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(0),
                    child: _DockItemContent(
                      icon: items[0].icon,
                      label: items[0].label,
                      selected: selectedIndex == 0,
                      isDark: isDark,
                    ),
                  ),
                ),
                // Матчи
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(1),
                    child: _DockItemContent(
                      icon: items[1].icon,
                      label: items[1].label,
                      selected: selectedIndex == 1,
                      isDark: isDark,
                    ),
                  ),
                ),
                // Круглая кнопка AI
                GestureDetector(
                  onTap: onOpenChat,
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.08),
                      border: Border.all(
                        color: isDark ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: const Icon(Icons.sports_soccer_rounded, color: Colors.white54, size: 22),
                  ),
                ),
                // Турниры
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(2),
                    child: _DockItemContent(
                      icon: items[2].icon,
                      label: items[2].label,
                      selected: selectedIndex == 2,
                      isDark: isDark,
                    ),
                  ),
                ),
                // Сохранённое
                Expanded(
                  child: GestureDetector(
                    onTap: () => onSelect(3),
                    child: _DockItemContent(
                      icon: items[3].icon,
                      label: items[3].label,
                      selected: selectedIndex == 3,
                      isDark: isDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DockItemContent extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool isDark;
  const _DockItemContent({required this.icon, required this.label, required this.selected, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: selected
                ? (isDark ? Colors.white : const Color(0xFF4A90E2))
                : (isDark ? Colors.white.withOpacity(0.55) : Colors.black38),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? (isDark ? Colors.white : const Color(0xFF4A90E2))
                  : (isDark ? Colors.white.withOpacity(0.6) : Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _OverviewTab({required this.onOpenAssistant});

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      _QuickActionData(
        title: tr('Индекс силы клуба', 'Club Power Index'),
        subtitle: tr('Отслеживайте форму, сдвиги рейтинга и сезонный импульс.', 'Track form, ranking shifts and season momentum.'),
        icon: Icons.stacked_line_chart_rounded,
        colors: const [Color(0xFF1746A2), Color(0xFF5F9DF7)],
        onTap: () => onOpenAssistant(
          draft: 'Покажи ключевые изменения в рейтингах UEFA за последний период',
        ),
      ),
      _QuickActionData(
        title: tr('Сравнение команд', 'Team Comparison'),
        subtitle: tr('Сравните два клуба перед важным матчем.', 'Compare two clubs before a decisive fixture.'),
        icon: Icons.compare_arrows_rounded,
        colors: const [Color(0xFF0F766E), Color(0xFF34D399)],
        onTap: () => onOpenAssistant(
          draft: 'Сравни две команды по силе и текущему положению в рейтингах UEFA',
        ),
      ),
      _QuickActionData(
        title: tr('Радар игрока', 'Player Radar'),
        subtitle: tr('Откройте короткий скаутский профиль.', 'Open a concise scouting-style briefing.'),
        icon: Icons.radar_rounded,
        colors: const [Color(0xFF9A3412), Color(0xFFF59E0B)],
        onTap: () => onOpenAssistant(
          draft: 'Сделай краткий аналитический профиль игрока и его сильных сторон',
        ),
      ),
    ];

    final insightCards = [
      const _InsightCardData(
        eyebrow: 'Focus',
        title: 'Pre-match briefings',
        description:
            'Short matchday summaries for clubs, players and UEFA context.',
      ),
      const _InsightCardData(
        eyebrow: 'Workflow',
        title: 'Scenario planning',
        description:
            'Use prepared entry points instead of starting from an empty chat.',
      ),
      const _InsightCardData(
        eyebrow: 'Benefit',
        title: 'Faster decisions',
        description:
            'The product now feels closer to a sports intelligence hub than a bot.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Быстрые сценарии', 'Quick actions'),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Точки входа, которые ощущаются как функции продукта, а не как подсказки для чата.',
            'Entry points that feel like product features instead of chat prompts.',
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.68),
          ),
        ),
        const SizedBox(height: 16),
        ...quickActions.map(
          (action) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _QuickActionCard(action: action),
          ),
        ),
        const SizedBox(height: 14),
        _SectionPanel(
          title: tr('Внутри Sportsense', 'Inside Sportsense'),
          subtitle: tr(
            'Главный экран с продуктовыми секциями, а не с пустым полем запроса.',
            'A front page with product sections, not a blank prompt field.',
          ),
          child: Column(
            children: insightCards
                .map(
                  (card) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InsightCard(card: card),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ignore: unused_element
class _MatchesTab extends StatelessWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _MatchesTab({required this.onOpenAssistant});

  @override
  Widget build(BuildContext context) {
    final matches = [
      const _MatchCardData(
        competition: 'UEFA Champions League',
        kickoff: 'Tonight • 20:45',
        homeTeam: 'Real Madrid',
        awayTeam: 'Manchester City',
        homeTrend: '+6%',
        awayTrend: '+4%',
        accent: Color(0xFF2563EB),
      ),
      const _MatchCardData(
        competition: 'Europa League',
        kickoff: 'Tomorrow • 19:30',
        homeTeam: 'Liverpool',
        awayTeam: 'Atalanta',
        homeTrend: '+8%',
        awayTrend: '+2%',
        accent: Color(0xFFEA580C),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured matches',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        ...matches.map(
          (match) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _MatchCard(
              data: match,
              onPreview: () => onOpenAssistant(
                draft:
                    'Сделай предматчевый разбор ${match.homeTeam} против ${match.awayTeam}',
              ),
            ),
          ),
        ),
        _SectionPanel(
          title: 'Momentum cues',
          subtitle:
              'Fast signals for who is climbing, stabilizing or under pressure before kickoff.',
          child: const Column(
            children: [
              _SignalRow(
                label: 'High tempo',
                value: 'Manchester City',
                accent: Color(0xFF34D399),
              ),
              _SignalRow(
                label: 'Set-piece edge',
                value: 'Real Madrid',
                accent: Color(0xFF7DD3FC),
              ),
              _SignalRow(
                label: 'Risk watch',
                value: 'Atalanta back line',
                accent: Color(0xFFF59E0B),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MatchesTabLive extends StatefulWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _MatchesTabLive({required this.onOpenAssistant});

  @override
  State<_MatchesTabLive> createState() => _MatchesTabLiveState();
}

class _MatchesTabLiveState extends State<_MatchesTabLive> {
  static const String _allLeaguesKey = '__all__';

  late Future<MatchFeed> _matchesFuture;
  String _selectedLeagueId = _allLeaguesKey;

  @override
  void initState() {
    super.initState();
    _matchesFuture = MatchesService().fetchMatchFeed();
  }

  Future<void> _refresh() async {
    setState(() {
      _matchesFuture = MatchesService().fetchMatchFeed();
    });
    await _matchesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                tr('Актуальные матчи', 'Current matches'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'События загружаются по текущей дате из футбольного расписания.',
            'Events are loaded for the current date from the football schedule feed.',
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.68),
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<MatchFeed>(
          future: _matchesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _MatchesLoadingState();
            }

            if (snapshot.hasError) {
              return _SectionPanel(
                title: tr('Не удалось загрузить матчи', 'Could not load matches'),
                subtitle: tr(
                  'Проверьте соединение или повторите обновление позже.',
                  'Check the connection or try refreshing again later.',
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _GhostButton(
                    label: tr('Обновить', 'Refresh'),
                    icon: Icons.refresh_rounded,
                    onTap: _refresh,
                  ),
                ),
              );
            }

            final feed = snapshot.data;
            final allMatches = feed?.matches ?? const <MatchItem>[];
            final leagues = feed?.leagues ?? const <LeagueOption>[];

            if (allMatches.isEmpty) {
              return _SectionPanel(
                title: tr('Матчей не найдено', 'No matches found'),
                subtitle: tr(
                  'На сегодня и завтра футбольных событий не найдено.',
                  'No football events were found for today and tomorrow.',
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: _GhostButton(
                    label: tr('Открыть сводку UEFA', 'Open UEFA Snapshot'),
                    icon: Icons.insights_rounded,
                    onTap: () => widget.onOpenAssistant(
                      draft:
                          'Дай краткую сводку по текущему состоянию рейтингов UEFA',
                    ),
                  ),
                ),
              );
            }

            final filteredMatches = _selectedLeagueId == _allLeaguesKey
                ? allMatches
                : allMatches
                    .where((match) => match.leagueId == _selectedLeagueId)
                    .toList();

            final visibleMatches =
                filteredMatches.isEmpty ? allMatches : filteredMatches;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (leagues.isNotEmpty) ...[
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _LeagueChip(
                          label: tr('Все матчи', 'All matches'),
                          selected: _selectedLeagueId == _allLeaguesKey,
                          onTap: () {
                            setState(() {
                              _selectedLeagueId = _allLeaguesKey;
                            });
                          },
                        ),
                        ...leagues.map(
                          (league) => _LeagueChip(
                            label: league.name,
                            selected: _selectedLeagueId == league.id,
                            onTap: () {
                              setState(() {
                                _selectedLeagueId = league.id;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (filteredMatches.isEmpty && _selectedLeagueId != _allLeaguesKey)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      tr(
                        'В выбранной лиге матчей не найдено, показываем все доступные события.',
                        'No matches were found in the selected league, showing all available events.',
                      ),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.68),
                      ),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                ...visibleMatches.map(
                  (match) => Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _LiveMatchCard(
                      match: match,
                      onPreview: () => widget.onOpenAssistant(
                        draft: tr(
                          'Сделай предматчевый разбор ${match.homeTeam} против ${match.awayTeam}',
                          'Create a pre-match briefing for ${match.homeTeam} vs ${match.awayTeam}',
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _TournamentsTab extends StatelessWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _TournamentsTab({required this.onOpenAssistant});

  @override
  Widget build(BuildContext context) {
    final tournaments = [
      const _TournamentTileData(
        name: 'Champions League',
        note: 'Knockout pressure rising',
        accent: Color(0xFF2563EB),
      ),
      const _TournamentTileData(
        name: 'Europa League',
        note: 'Unexpected movers in the race',
        accent: Color(0xFFEA580C),
      ),
      const _TournamentTileData(
        name: 'UEFA Coefficient',
        note: 'Country battle tightening',
        accent: Color(0xFF0F766E),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Турнирные разделы', 'Competition hubs'),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Просматривайте ключевые турнирные линии перед переходом к глубокой аналитике.',
            'Browse the big tournament narratives before opening deeper analysis.',
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.68),
          ),
        ),
        const SizedBox(height: 16),
        ...tournaments.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TournamentTile(
              data: item,
              onTap: () => onOpenAssistant(
                draft: 'Дай сводку по турниру ${item.name} и ключевым изменениям',
              ),
            ),
          ),
        ),
        _SectionPanel(
          title: 'Race board',
          subtitle:
              'Three storylines to keep on top of this week across UEFA competitions.',
          child: const Column(
            children: [
              _SignalRow(
                label: 'Top riser',
                value: 'Leverkusen coefficient momentum',
                accent: Color(0xFF34D399),
              ),
              _SignalRow(
                label: 'Pressure point',
                value: 'Fourth pot reshuffle risk',
                accent: Color(0xFFF59E0B),
              ),
              _SignalRow(
                label: 'Watch next',
                value: 'Country ranking swing',
                accent: Color(0xFF7DD3FC),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SavedTab extends StatelessWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _SavedTab({required this.onOpenAssistant});

  @override
  Widget build(BuildContext context) {
    final savedItems = [
      const _WatchlistItemData(
        title: 'Manchester City',
        subtitle: 'Club brief shortcut',
        icon: Icons.shield_rounded,
      ),
      const _WatchlistItemData(
        title: 'Jude Bellingham',
        subtitle: 'Player radar snapshot',
        icon: Icons.person_rounded,
      ),
      const _WatchlistItemData(
        title: 'UEFA ranking monitor',
        subtitle: 'Weekly trend summary',
        icon: Icons.query_stats_rounded,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Сохранено на потом', 'Saved for later'),
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Лёгкий watchlist, который ощущается как библиотека спортивного приложения.',
            'A lightweight watchlist that feels closer to a sports app library.',
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.68),
          ),
        ),
        const SizedBox(height: 16),
        ...savedItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _WatchlistTile(
              data: item,
              onTap: () => onOpenAssistant(
                draft: 'Подготовь обновленную сводку по ${item.title}',
              ),
            ),
          ),
        ),
        _SectionPanel(
          title: 'Library shortcuts',
          subtitle:
              'Use saved entities as persistent starting points instead of typing repeated prompts.',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GhostButton(
                label: 'Club form brief',
                icon: Icons.article_rounded,
                onTap: () => onOpenAssistant(
                  draft: 'Сделай сводку по текущей форме сохраненного клуба',
                ),
              ),
              _GhostButton(
                label: 'Player outlook',
                icon: Icons.radar_rounded,
                onTap: () => onOpenAssistant(
                  draft: 'Подготовь краткий outlook по сохраненному игроку',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionPanel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              height: 1.45,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _SignalRow({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeagueChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LeagueChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF102A43)
                  : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchesLoadingState extends StatelessWidget {
  const _MatchesLoadingState();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        3,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Container(
            height: 156,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  final MatchItem match;
  final VoidCallback onPreview;

  const _LiveMatchCard({
    required this.match,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final localKickoff = match.kickoff.toLocal();
    final scoreAvailable =
        match.homeScore != null &&
        match.awayScore != null &&
        match.homeScore!.isNotEmpty &&
        match.awayScore!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  match.competition,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7DD3FC),
                  ),
                ),
              ),
              Text(
                _formatMatchDateTime(localKickoff),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _LiveTeamRow(
            name: match.homeTeam,
            badgeUrl: match.homeBadge,
            trailing: scoreAvailable ? match.homeScore! : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _LiveTeamRow(
            name: match.awayTeam,
            badgeUrl: match.awayBadge,
            trailing: scoreAvailable ? match.awayScore! : null,
          ),
          const SizedBox(height: 14),
          if (match.venue != null && match.venue!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                '${tr('Стадион', 'Venue')}: ${match.venue!}',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.68),
                ),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: _GhostButton(
              label: tr('Разбор матча', 'Match briefing'),
              icon: Icons.arrow_forward_rounded,
              onTap: onPreview,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMatchDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month  $hour:$minute';
  }
}

class _LiveTeamRow extends StatelessWidget {
  final String name;
  final String? badgeUrl;
  final String? trailing;

  const _LiveTeamRow({
    required this.name,
    required this.badgeUrl,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _BadgeAvatar(imageUrl: badgeUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
      ],
    );
  }
}

class _BadgeAvatar extends StatelessWidget {
  final String? imageUrl;

  const _BadgeAvatar({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl == null || imageUrl!.isEmpty
          ? const Icon(Icons.shield_rounded, color: Colors.white70)
          : Image.network(
              imageUrl!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.shield_rounded, color: Colors.white70);
              },
            ),
    );
  }
}

class _MatchCardData {
  final String competition;
  final String kickoff;
  final String homeTeam;
  final String awayTeam;
  final String homeTrend;
  final String awayTrend;
  final Color accent;

  const _MatchCardData({
    required this.competition,
    required this.kickoff,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeTrend,
    required this.awayTrend,
    required this.accent,
  });
}

class _MatchCard extends StatelessWidget {
  final _MatchCardData data;
  final VoidCallback onPreview;

  const _MatchCard({required this.data, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: data.accent.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  data.competition,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                data.kickoff,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _TeamLine(name: data.homeTeam, trend: data.homeTrend),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _TeamLine(name: data.awayTeam, trend: data.awayTrend),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerLeft,
            child: _GhostButton(
              label: 'Preview matchup',
              icon: Icons.arrow_forward_rounded,
              onTap: onPreview,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamLine extends StatelessWidget {
  final String name;
  final String trend;

  const _TeamLine({required this.name, required this.trend});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            trend,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF34D399),
            ),
          ),
        ),
      ],
    );
  }
}

class _TournamentTileData {
  final String name;
  final String note;
  final Color accent;

  const _TournamentTileData({
    required this.name,
    required this.note,
    required this.accent,
  });
}

class _TournamentTile extends StatelessWidget {
  final _TournamentTileData data;
  final VoidCallback onTap;

  const _TournamentTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 14,
                height: 48,
                decoration: BoxDecoration(
                  color: data.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.name,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.note,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _WatchlistItemData {
  final String title;
  final String subtitle;
  final IconData icon;

  const _WatchlistItemData({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

class _WatchlistTile extends StatelessWidget {
  final _WatchlistItemData data;
  final VoidCallback onTap;

  const _WatchlistTile({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(data.icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= CHAT SESSION =======================
class ChatSession {
  String id;
  String title;
  List<ChatMessage> messages;
  ChatSession({required this.id, required this.title, required this.messages});
}

// ======================= EMERGENCY APP =======================
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
            ],
          ),
        ),
      ),
    ),
  );
}

// ======================= INIT SERVICES =======================
Future<Map<String, dynamic>?> _initializeAppState() async {
  try {
    final vectorDbManager = VectorDatabaseManager(useLocalOnly: true);
    await vectorDbManager.initialize();

    final queryVectorizer = UserQueryVectorizerService(
      dbManager: vectorDbManager,
    );
    await queryVectorizer.initialize();

    final rankingsApi = UefaRankingsApiService();
    final rankingsApiAvailable = await rankingsApi.isAvailable();

    final uefaParser = UefaParser(
      vectorDbManager: vectorDbManager,
      rankingsApi: rankingsApi,
    );
    final rankingsSearch = RankingsVectorSearch(dbManager: vectorDbManager);

    final qwenApi = QwenApiService(baseUrl: QWEN_API_URL);
    final qwenAvailable = await qwenApi.isAvailable();

    final hfApi = HuggingFaceApiService();
    final hfAvailable = await hfApi.initialize();
    if (hfAvailable) {
      print('✅ HuggingFace API (Mistral 7B) доступен');
    } else {
      print('⚠️ HuggingFace API недоступен — проверьте HF_TOKEN в .env');
    }

    return {
      'vectorDbManager': vectorDbManager,
      'queryVectorizer': queryVectorizer,
      'uefaParser': uefaParser,
      'qwenApi': qwenApi,
      'hfApi': hfApi,
      'rankingsSearch': rankingsSearch,
      'rankingsApiAvailable': rankingsApiAvailable,
      'qwenAvailable': qwenAvailable,
      'hfAvailable': hfAvailable,
    };
  } catch (e, stackTrace) {
    print('❌ Ошибка инициализации: $e\n$stackTrace');
    return null;
  }
}
