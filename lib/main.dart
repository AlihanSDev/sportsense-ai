import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math' as math;

// ======================= СЕРВИСЫ =======================
import 'services/theme_notifier.dart';
import 'services/uefa_search_manager.dart';
import 'services/vector_db_manager.dart';
import 'services/user_query_vectorizer.dart';
import 'services/rankings_relevance_service.dart';
import 'services/uefa_parser.dart';
import 'services/qwen_api_service.dart';
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

String tr(String ru, String en) => languageNotifier.isRussian ? ru : en;

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
  ChatMessage({required this.text, required this.isUser, this.textColor});
}

class TournamentItem {
  final String id;
  final String country;
  final String flag;
  final String name;
  final String firstLetter;
  final int? leagueId;
  final int? season;

  const TournamentItem({
    required this.id,
    required this.country,
    required this.flag,
    required this.name,
    required this.firstLetter,
    this.leagueId,
    this.season,
  });
}

// ======================= MAIN =======================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
          rankingsSearch: appState['rankingsSearch'],
          rankingsApiAvailable: appState['rankingsApiAvailable'],
          qwenAvailable: appState['qwenAvailable'],
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
      locale: const Locale('ru'),
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
        rankingsSearch: rankingsSearch,
        rankingsApiAvailable: rankingsApiAvailable,
        qwenAvailable: qwenAvailable,
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
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;

  const HomeScreen({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
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
          rankingsSearch: rankingsSearch,
          rankingsApiAvailable: rankingsApiAvailable,
          qwenAvailable: qwenAvailable,
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
        value: widget.qwenAvailable
            ? tr('готов', 'ready')
            : tr('ожидание', 'standby'),
        active: widget.qwenAvailable,
      ),
      _StatusItem(
        label: tr('Режим', 'Mode'),
        value: tr('матчдэй', 'matchday'),
        active: true,
      ),
    ];

    final navItems = [
      _NavItem(label: tr('Главная', 'Home'), icon: Icons.home_rounded),
      _NavItem(
        label: tr('Матчи', 'Matches'),
        icon: Icons.sports_soccer_rounded,
      ),
      _NavItem(
        label: tr('Турниры', 'Tournaments'),
        icon: Icons.emoji_events_rounded,
      ),
      _NavItem(label: tr('Сохраненное', 'Saved'), icon: Icons.bookmark_rounded),
    ];

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
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
      tr(
        'Живой матчдэй с быстрым контекстом.',
        'Live matchday view with quick context.',
      ),
      tr(
        'Турниры, интриги и движение по сетке.',
        'Competitions, race tables and storylines.',
      ),
      tr(
        'Сохранённые клубы, игроки и быстрые сводки.',
        'Saved clubs, players and briefing shortcuts.',
      ),
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
                colors: [
                  Color(0xFF102A43),
                  Color(0xFF1E5F74),
                  Color(0xFF3BA99C),
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF4A90E2),
                  Color(0xFF357ABD),
                  Color(0xFF3BA99C),
                ],
              ),
        border: Border.all(
          color: isDark
              ? Colors.white.withOpacity(0.12)
              : Colors.black.withOpacity(0.06),
        ),
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
              color: isDark
                  ? Colors.white.withOpacity(0.14)
                  : Colors.white.withOpacity(0.25),
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
            children: statusItems
                .map((item) => _StatusPill(item: item))
                .toList(),
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
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;
  final String? initialDraft;

  const ChatScreen({
    super.key,
    required this.vectorDbManager,
    required this.queryVectorizer,
    required this.uefaParser,
    required this.qwenApi,
    required this.rankingsSearch,
    required this.rankingsApiAvailable,
    required this.qwenAvailable,
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
  bool _isInitializing = true; // Флаг инициализации
  bool _isGenerating = false; // Флаг генерации ответа
  bool _stopRequested = false; // Флаг остановки
  bool _useSearch = false; // Флаг поиска в интернете

  ChatSession? get _currentChatOrNull =>
      _chats.isNotEmpty ? _chats[_currentChatIndex] : null;
  ChatSession get currentChat => _chats.isNotEmpty
      ? _chats[_currentChatIndex]
      : ChatSession(id: '0', title: '', messages: []);

  @override
  void initState() {
    super.initState();
    _uefaSearchManager = UefaSearchManager();
    _uefaSearchManager.initialize();
    _uefaSearchManager.addListener(_onUefaSearchChanged);

    // Запускаем инициализацию и создаём чат сразу
    _createNewChat();
    _checkAuth(); // Асинхронная проверка, не блокирует
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
              text:
                  '⚠️ UEFA Rankings API недоступен.\nЗапустите: python scripts/uefa_parser_api.py',
              isUser: false,
              textColor: const Color(0xFFB37B7B),
            ),
          );
        }

        if (!widget.qwenAvailable) {
          chat.messages.add(
            ChatMessage(
              text:
                  '⚠️ Qwen API недоступен.\nЗапустите: python scripts/qwen_api.py',
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
            _chats.add(
              ChatSession(
                id: chat.id.toString(),
                title: chat.title,
                messages: [],
              ),
            );
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
            chat.messages.add(ChatMessage(text: msg.text, isUser: msg.isUser));
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
      _db
          .createChat(userId: _currentUser!.id!, title: newChat.title)
          .then((savedChat) {
            if (savedChat != null && mounted) {
              setState(() {
                newChat.id = savedChat.id.toString();
              });
            }
          })
          .catchError((e) {
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
          currentChat.messages.add(
            ChatMessage(
              text: info,
              isUser: false,
              textColor: const Color(0xFF7C4DFF),
            ),
          );
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
          currentChat.messages.add(
            ChatMessage(
              text: '🍌 БАНАН! 🍌',
              isUser: false,
              textColor: const Color(0xFFFFD700),
            ),
          );
        });
      }
      return;
    }

    if (text == 'TEXT-IDLE') {
      setState(() {
        currentChat.messages.add(ChatMessage(text: text, isUser: true));
      });
      await Future.delayed(const Duration(seconds: 3));
      final reply =
          'Это пример генерируемого текста. Он появляется постепенно, словно AI печатает его прямо сейчас.';
      if (mounted) {
        setState(() {
          currentChat.messages.add(
            ChatMessage(
              text: reply,
              isUser: false,
              textColor: const Color(0xFF7C4DFF),
            ),
          );
        });
      }
      return;
    }

    // Сохраняем сообщение пользователя в SQLite
    if (_isLoggedIn &&
        _currentUser != null &&
        currentChat.id != null &&
        currentChat.id != '0') {
      final chatId = int.parse(currentChat.id!);
      _db.addMessage(chatId: chatId, text: text, isUser: true).catchError((e) {
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
      'найди в интернете',
      'найди в сети',
      'поищи в интернете',
      'поищи в сети',
      'search the internet',
      'search the web',
      'find online',
      'look up',
      'найди онлайн',
      'погугли',
      'google it',
      'search online',
    ];
    final shouldSearch =
        _useSearch || searchTriggers.any((t) => text.toLowerCase().contains(t));

    String ragContext = '';

    if (_stopRequested) {
      _cancelGeneration();
      return;
    }

    if (relevance >= 2.0) {
      await widget.uefaParser.parseAndSaveRankings();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (_stopRequested) {
      _cancelGeneration();
      return;
    }

    if (relevance >= 1.0) {
      ragContext = await widget.rankingsSearch.getRagContext(text, limit: 10);
    }

    if (_stopRequested) {
      _cancelGeneration();
      return;
    }

    // Добавляем пустое сообщение бота, которое будем заполнять
    final botMsgIndex = currentChat.messages.length;
    if (mounted) {
      setState(() {
        currentChat.messages.add(
          ChatMessage(text: '', isUser: false, textColor: textColor),
        );
      });
    }

    String botResponse;
    if (widget.qwenAvailable) {
      final qwenResponse = await widget.qwenApi.chat(
        text,
        context: ragContext.isNotEmpty ? ragContext : null,
        maxTokens: 1024,
      );
      if (_stopRequested) {
        _cancelGeneration();
        return;
      }
      botResponse =
          qwenResponse?.response ??
          'Произошла ошибка при обработке запроса. Попробуйте ещё раз.';
    } else {
      // Имитация постепенной генерации
      botResponse =
          'Спасибо за вопрос! В данный момент я готовлю ответ по вашему запросу: "$text"';
      if (ragContext.isNotEmpty) botResponse += '\n\n$ragContext';

      // Анимация посимвольного появления
      for (int i = 1; i <= botResponse.length; i++) {
        if (_stopRequested) {
          _cancelGeneration();
          return;
        }
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
      setState(() {
        _isGenerating = false;
      });
      return;
    }

    if (_stopRequested) {
      _cancelGeneration();
      return;
    }

    // Анимация посимвольного появления ответа LLM
    for (int i = 1; i <= botResponse.length; i++) {
      if (_stopRequested) {
        _cancelGeneration();
        return;
      }
      if (mounted) {
        setState(() {
          currentChat.messages[botMsgIndex] = ChatMessage(
            text: botResponse.substring(0, i),
            isUser: false,
            textColor: textColor,
          );
        });
      }
      await Future.delayed(const Duration(milliseconds: 12));
    }

    // Сохраняем ответ бота в SQLite
    if (_isLoggedIn &&
        _currentUser != null &&
        currentChat.id != null &&
        currentChat.id != '0') {
      final chatId = int.parse(currentChat.id!);
      _db
          .addMessage(chatId: chatId, text: botResponse, isUser: false)
          .catchError((e) {
            print('Ошибка сохранения ответа: $e');
            return null;
          });
    }

    setState(() {
      _isGenerating = false;
    });
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
      backgroundColor: Colors.transparent,
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  // Стрелка назад
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_rounded,
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 4),
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(
                        Icons.menu_rounded,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  tr('АНАЛИТИКА ПО ЗАПРОСУ', 'ON-DEMAND ANALYSIS'),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
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
                        onTap: () => _controller.text =
                            'Дай краткую сводку по текущему состоянию рейтингов UEFA',
                      ),
                      _PromptChip(
                        label: tr('Сравнить клубы', 'Compare clubs'),
                        onTap: () => _controller.text =
                            'Сравни две команды по форме и силе в рейтинге UEFA',
                      ),
                      _PromptChip(
                        label: tr('Профиль игрока', 'Player brief'),
                        onTap: () => _controller.text =
                            'Подготовь короткий аналитический профиль игрока',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Сообщения
              Expanded(
                child: _chats.isEmpty
                    ? const Center(
                        child: Text(
                          'Загрузка чата...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    : ListView.builder(
                        controller: ScrollController(),
                        itemCount: currentChat.messages.length,
                        itemBuilder: (context, index) {
                          final msg = currentChat.messages[index];
                          // Показываем индикатор поиска вместо typing когда включён поиск
                          if (msg.text.isEmpty && !msg.isUser) {
                            return _useSearch
                                ? const _SearchIndicator()
                                : const _TypingIndicator();
                          }
                          return Align(
                            alignment: msg.isUser
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: msg.isUser
                                    ? Colors.blue
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                msg.text,
                                style: TextStyle(
                                  color: msg.textColor ?? Colors.white,
                                ),
                              ),
                            ),
                          );
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4A90E2).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4A90E2).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.public_rounded,
                              size: 14,
                              color: Color(0xFF4A90E2),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              tr(
                                'Поиск в интернете включён',
                                'Web search enabled',
                              ),
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF4A90E2),
                              ),
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
                              color: _useSearch
                                  ? const Color(0xFF4A90E2)
                                  : Colors.white54,
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
                                  ? tr(
                                      'ИИ генерирует ответ...',
                                      'AI is generating...',
                                    )
                                  : tr(
                                      'Введите запрос для аналитики',
                                      'Enter an analysis request',
                                    ),
                              hintStyle: TextStyle(
                                color: _isGenerating
                                    ? Colors.white.withOpacity(0.3)
                                    : Colors.white54,
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
                                  icon: const Icon(
                                    Icons.stop_rounded,
                                    color: Color(0xFFEF5350),
                                  ),
                                  onPressed: () => _sendMessage(''),
                                  style: IconButton.styleFrom(
                                    backgroundColor: const Color(
                                      0xFFEF5350,
                                    ).withOpacity(0.15),
                                    shape: const CircleBorder(),
                                  ),
                                )
                              : IconButton(
                                  key: const ValueKey('send'),
                                  icon: const Icon(
                                    Icons.send_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _sendMessage(_controller.text),
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
              color: isDark
                  ? Colors.black.withOpacity(0.4)
                  : Colors.white.withOpacity(0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
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
      return Tween<double>(
        begin: 0.3,
        end: 1.0,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
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
    _rotation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
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

class _SearchDotsState extends State<_SearchDots>
    with TickerProviderStateMixin {
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
      return Tween<double>(
        begin: 0.2,
        end: 1.0,
      ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut));
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
                color: const Color(
                  0xFF4A90E2,
                ).withOpacity(_animations[i].value * 0.7),
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
  const _ChatNavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white.withOpacity(0.55) : Colors.black38,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white.withOpacity(0.6) : Colors.black54,
              ),
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
      backgroundColor: Colors.transparent,
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
                    subtitle: tr(
                      'Классический космос со звёздами',
                      'Classic space with stars',
                    ),
                    gradient: const [Color(0xFF0B0B12), Color(0xFF1A1A26)],
                    accent: const Color(0xFF8B7DD8),
                    onTap: () => themeNotifier.setTheme(AppTheme.dark),
                  ),
                  const SizedBox(height: 12),
                  _ThemeCard(
                    theme: AppTheme.sportsense,
                    current: themeNotifier.theme,
                    title: 'Sportsense',
                    subtitle: tr(
                      'Тёмный с геометрическими деталями',
                      'Dark with geometric details',
                    ),
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
                    subtitle: tr(
                      'Молочный фон с голубыми сотами',
                      'Milk-white with blue honeycombs',
                    ),
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
                              color: Colors.white.withOpacity(
                                0.4 + (i % 3) * 0.2,
                              ),
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
                      color: isDarkTheme
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
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
                  color: isSelected
                      ? accent
                      : (isDarkTheme ? Colors.white30 : Colors.black26),
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
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
    final accent = item.active
        ? const Color(0xFF34D399)
        : const Color(0xFFF97316);
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
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
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
                      color: isDark
                          ? Colors.white.withOpacity(0.12)
                          : Colors.black.withOpacity(0.08),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withOpacity(0.15)
                            : Colors.black.withOpacity(0.12),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.sports_soccer_rounded,
                      color: Colors.white54,
                      size: 22,
                    ),
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
  const _DockItemContent({
    required this.icon,
    required this.label,
    required this.selected,
    required this.isDark,
  });

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

class _OverviewTab extends StatefulWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _OverviewTab({required this.onOpenAssistant});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  final MatchesService _matchesService = MatchesService();
  late Future<List<FootballMatch>> _liveMatchesFuture;

  static const List<_HomeNewsItem> _newsItems = [
    _HomeNewsItem(
      title: 'Пари Сен-Жермен готовит новый контракт для лидера',
      time: '15 мин назад',
      imageUrl:
          'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=900&q=80',
    ),
    _HomeNewsItem(
      title: 'Манчестер Сити не хочет отпускать игрока до лета',
      time: '42 мин назад',
      imageUrl:
          'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=900&q=80',
    ),
    _HomeNewsItem(
      title: 'Сборная дня: главные европейские матчи вечера',
      time: '1 ч назад',
      imageUrl:
          'https://images.unsplash.com/photo-1547347298-4074fc3086f0?auto=format&fit=crop&w=900&q=80',
    ),
  ];

  static const List<_PopularLeagueItem> _popularLeagues = [
    _PopularLeagueItem(name: 'Премьер-лига', country: 'Англия', accent: '🇬🇧'),
    _PopularLeagueItem(name: 'Лига чемпионов', country: 'Европа', accent: '🏆'),
    _PopularLeagueItem(name: 'Бундеслига', country: 'Германия', accent: '🇩🇪'),
    _PopularLeagueItem(name: 'Ла Лига', country: 'Испания', accent: '🇪🇸'),
    _PopularLeagueItem(name: 'Серия А', country: 'Италия', accent: '🇮🇹'),
  ];

  @override
  void initState() {
    super.initState();
    _liveMatchesFuture = _matchesService.getLiveMatches();
  }

  Future<void> _reloadLive() async {
    setState(() {
      _liveMatchesFuture = _matchesService.getLiveMatches();
    });
    await _liveMatchesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Футбол',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Сегодня • LIVE',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.68),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _reloadLive,
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const _HomeSectionTitle(title: 'LIVE матчи'),
        const SizedBox(height: 12),
        FutureBuilder<List<FootballMatch>>(
          future: _liveMatchesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 176,
                child: _HomeHorizontalLoading(),
              );
            }

            if (snapshot.hasError) {
              final message = snapshot.error is ApiFootballException
                  ? (snapshot.error as ApiFootballException).message
                  : 'Не удалось загрузить LIVE матчи';
              return _HomeInlineState(message: message);
            }

            final matches = snapshot.data ?? const <FootballMatch>[];
            if (matches.isEmpty) {
              return const _HomeInlineState(message: 'Сейчас live-матчей нет.');
            }

            return SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: matches.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final match = matches[index];
                  return _HomeLiveMatchCard(match: match);
                },
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        const _HomeSectionTitle(title: 'Новости'),
        const SizedBox(height: 12),
        ..._newsItems.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HomeNewsCard(item: item),
          ),
        ),
        const SizedBox(height: 24),
        const _HomeSectionTitle(title: 'Популярные турниры'),
        const SizedBox(height: 12),
        ..._popularLeagues.map(
          (league) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PopularLeagueTile(item: league),
          ),
        ),
      ],
    );
  }
}

class _HomeSectionTitle extends StatelessWidget {
  final String title;

  const _HomeSectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.spaceGrotesk(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: Colors.white,
      ),
    );
  }
}

class _HomeLiveMatchCard extends StatelessWidget {
  final FootballMatch match;

  const _HomeLiveMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final scoreAvailable = match.homeScore != null && match.awayScore != null;
    final elapsed = match.elapsed != null ? "${match.elapsed}'" : 'LIVE';

    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            match.leagueName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF7DD3FC),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$elapsed • ${match.statusShort}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.65),
            ),
          ),
          const SizedBox(height: 12),
          _HomeLiveTeamRow(
            name: match.homeTeam,
            logo: match.homeLogo,
            score: scoreAvailable ? '${match.homeScore}' : null,
          ),
          const SizedBox(height: 8),
          _HomeLiveTeamRow(
            name: match.awayTeam,
            logo: match.awayLogo,
            score: scoreAvailable ? '${match.awayScore}' : null,
          ),
        ],
      ),
    );
  }
}

class _HomeLiveTeamRow extends StatelessWidget {
  final String name;
  final String? logo;
  final String? score;

  const _HomeLiveTeamRow({
    required this.name,
    required this.logo,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _BadgeAvatar(imageUrl: logo),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        if (score != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              score!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

class _HomeInlineState extends StatelessWidget {
  final String message;

  const _HomeInlineState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white.withOpacity(0.78),
        ),
      ),
    );
  }
}

class _HomeHorizontalLoading extends StatelessWidget {
  const _HomeHorizontalLoading();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return Container(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
        );
      },
    );
  }
}

class _HomeNewsItem {
  final String title;
  final String time;
  final String imageUrl;

  const _HomeNewsItem({
    required this.title,
    required this.time,
    required this.imageUrl,
  });
}

class _HomeNewsCard extends StatelessWidget {
  final _HomeNewsItem item;

  const _HomeNewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 112,
            height: 112,
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.white.withOpacity(0.06),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: Colors.white70,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.time,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.58),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PopularLeagueItem {
  final String name;
  final String country;
  final String accent;

  const _PopularLeagueItem({
    required this.name,
    required this.country,
    required this.accent,
  });
}

class _PopularLeagueTile extends StatelessWidget {
  final _PopularLeagueItem item;

  const _PopularLeagueTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(item.accent, style: const TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.country,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.48),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
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
  final MatchesService _matchesService = MatchesService();
  late Future<MatchFeed> _matchesFuture;
  bool _showLive = false;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  Future<MatchFeed> _loadMatches() {
    return _matchesService.fetchMatchFeed(liveOnly: _showLive);
  }

  Future<void> _refresh() async {
    setState(() {
      _matchesFuture = _loadMatches();
    });
    await _matchesFuture;
  }

  void _selectMode(bool showLive) {
    if (_showLive == showLive) return;
    setState(() {
      _showLive = showLive;
      _matchesFuture = _loadMatches();
    });
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
            'Используем API-FOOTBALL: переключайтесь между сегодняшними матчами и LIVE-событиями.',
            'Powered by API-FOOTBALL: switch between today fixtures and live events.',
          ),
          style: GoogleFonts.inter(
            fontSize: 14,
            color: Colors.white.withOpacity(0.68),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 40,
          child: Row(
            children: [
              _LeagueChip(
                label: tr('Сегодня', 'Today'),
                selected: !_showLive,
                onTap: () => _selectMode(false),
              ),
              _LeagueChip(
                label: 'LIVE',
                selected: _showLive,
                onTap: () => _selectMode(true),
              ),
            ],
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
                title: tr(
                  'Не удалось загрузить матчи',
                  'Could not load matches',
                ),
                subtitle: _matchErrorMessage(snapshot.error),
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
            final allMatches = feed?.matches ?? const <FootballMatch>[];
            final leagues = feed?.leagues ?? const <LeagueOption>[];

            if (allMatches.isEmpty) {
              return _SectionPanel(
                title: tr('Матчей не найдено', 'No matches found'),
                subtitle: tr(
                  _showLive
                      ? 'Сейчас live-матчей не найдено.'
                      : 'На сегодня футбольных матчей не найдено.',
                  _showLive
                      ? 'No live football matches were found right now.'
                      : 'No football matches were found for today.',
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

            final groupedMatches = <String, List<FootballMatch>>{};
            for (final match in allMatches) {
              final leagueKey = '${match.leagueId}';
              groupedMatches
                  .putIfAbsent(leagueKey, () => <FootballMatch>[])
                  .add(match);
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...leagues.map((league) {
                  final matches =
                      groupedMatches[league.id] ?? const <FootballMatch>[];
                  if (matches.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: _LeagueMatchesSection(
                      title: league.name,
                      country: matches.first.country,
                      children: matches
                          .map(
                            (match) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
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
                          )
                          .toList(),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ],
    );
  }

  String _matchErrorMessage(Object? error) {
    if (error is ApiFootballException) {
      return error.message;
    }
    final message = error?.toString();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    return tr(
      'Проверьте соединение или повторите обновление позже.',
      'Check the connection or try refreshing again later.',
    );
  }
}

class _TournamentsTab extends StatefulWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _TournamentsTab({required this.onOpenAssistant});

  @override
  State<_TournamentsTab> createState() => _TournamentsTabState();
}

class _TournamentsTabState extends State<_TournamentsTab> {
  static const List<String> _alphabet = [
    'А',
    'Б',
    'В',
    'Г',
    'Д',
    'Е',
    'Ж',
    'З',
    'И',
    'К',
    'Л',
    'М',
    'Н',
    'О',
    'П',
    'Р',
    'С',
    'Т',
    'У',
    'Ф',
    'Х',
    'Ч',
    'Ш',
    'Э',
    'Ю',
    'Я',
  ];

  static const List<TournamentItem> _allTournaments = [
    TournamentItem(
      id: 'asia-cup',
      country: 'Азия',
      flag: '🌏',
      name: 'Кубок Азии',
      firstLetter: 'К',
    ),
    TournamentItem(
      id: 'asia-champions-league',
      country: 'Азия',
      flag: '🌏',
      name: 'Лига чемпионов',
      firstLetter: 'Л',
    ),
    TournamentItem(
      id: 'afc-asian-cup-u17',
      country: 'Азия',
      flag: '🌏',
      name: 'AFC Asian Cup U17',
      firstLetter: 'А',
    ),
    TournamentItem(
      id: 'epl',
      country: 'Англия',
      flag: '🏴',
      name: 'Премьер-лига',
      firstLetter: 'П',
      leagueId: 39,
      season: 2025,
    ),
    TournamentItem(
      id: 'bundesliga',
      country: 'Германия',
      flag: '🇩🇪',
      name: 'Бундеслига',
      firstLetter: 'Б',
      leagueId: 78,
      season: 2025,
    ),
    TournamentItem(
      id: 'euro',
      country: 'Европа',
      flag: '🇪🇺',
      name: 'Евро',
      firstLetter: 'Е',
      leagueId: 4,
      season: 2025,
    ),
    TournamentItem(
      id: 'ucl',
      country: 'Европа',
      flag: '🇪🇺',
      name: 'Лига чемпионов',
      firstLetter: 'Л',
      leagueId: 2,
      season: 2025,
    ),
    TournamentItem(
      id: 'uel',
      country: 'Европа',
      flag: '🇪🇺',
      name: 'Лига Европы',
      firstLetter: 'Л',
      leagueId: 3,
      season: 2025,
    ),
    TournamentItem(
      id: 'conference-league',
      country: 'Европа',
      flag: '🇪🇺',
      name: 'Лига конференций',
      firstLetter: 'Л',
    ),
    TournamentItem(
      id: 'uefa-nations-league',
      country: 'Европа',
      flag: '🇪🇺',
      name: 'Лига наций УЕФА',
      firstLetter: 'Л',
      leagueId: 5,
      season: 2025,
    ),
    TournamentItem(
      id: 'la-liga',
      country: 'Испания',
      flag: '🇪🇸',
      name: 'Примера',
      firstLetter: 'П',
      leagueId: 140,
      season: 2025,
    ),
    TournamentItem(
      id: 'copa-del-rey',
      country: 'Испания',
      flag: '🇪🇸',
      name: 'Кубок Испании',
      firstLetter: 'К',
    ),
    TournamentItem(
      id: 'serie-a',
      country: 'Италия',
      flag: '🇮🇹',
      name: 'Серия А',
      firstLetter: 'С',
      leagueId: 135,
      season: 2025,
    ),
    TournamentItem(
      id: 'ligue-1',
      country: 'Франция',
      flag: '🇫🇷',
      name: 'Лига 1',
      firstLetter: 'Л',
      leagueId: 61,
      season: 2025,
    ),
    TournamentItem(
      id: 'primeira-liga',
      country: 'Португалия',
      flag: '🇵🇹',
      name: 'Примейра',
      firstLetter: 'П',
      leagueId: 94,
      season: 2025,
    ),
    TournamentItem(
      id: 'super-lig',
      country: 'Турция',
      flag: '🇹🇷',
      name: 'Суперлига',
      firstLetter: 'С',
      leagueId: 203,
      season: 2025,
    ),
  ];
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _favoriteIds = {'epl', 'ucl'};
  final Map<String, GlobalKey> _letterKeys = {
    for (final letter in _alphabet) letter: GlobalKey(),
  };
  String _query = '';

  List<TournamentItem> get _filteredTournaments {
    final normalized = _query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? List<TournamentItem>.from(_allTournaments)
        : _allTournaments.where((item) {
            final country = item.country.toLowerCase();
            final name = item.name.toLowerCase();
            return country.contains(normalized) || name.contains(normalized);
          }).toList();

    filtered.sort((a, b) {
      final letterCompare = a.firstLetter.compareTo(b.firstLetter);
      if (letterCompare != 0) return letterCompare;
      final countryCompare = a.country.compareTo(b.country);
      if (countryCompare != 0) return countryCompare;
      return a.name.compareTo(b.name);
    });

    return filtered;
  }

  List<TournamentItem> get _favoriteTournaments => _allTournaments
      .where(
        (item) =>
            _favoriteIds.contains(item.id) &&
            _filteredTournaments.any((filtered) => filtered.id == item.id),
      )
      .toList();

  void _toggleFavorite(String id) {
    setState(() {
      if (_favoriteIds.contains(id)) {
        _favoriteIds.remove(id);
      } else {
        _favoriteIds.add(id);
      }
    });
  }

  void _jumpToLetter(String letter) {
    final hasMatch = _filteredTournaments.any(
      (item) => item.firstLetter == letter,
    );
    if (!hasMatch) return;

    final keyContext = _letterKeys[letter]?.currentContext;
    if (keyContext == null) return;

    Scrollable.ensureVisible(
      keyContext,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: 0.08,
    );
  }

  void _openTournament(TournamentItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TournamentDetailsScreen(tournament: item),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredTournaments = _filteredTournaments;
    final favorites = _favoriteTournaments;
    final groupedLetters = <String>[
      for (final letter in _alphabet)
        if (filteredTournaments.any((item) => item.firstLetter == letter))
          letter,
    ];

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('Турниры', 'Tournaments'),
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                tr(
                  'Экран соревнований в духе live-score каталога: быстрый поиск, избранное и переход к деталям турнира.',
                  'A live-score style competitions screen with fast search, favorites and deep links into tournament details.',
                ),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.68),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              _TournamentSearchField(
                controller: _searchController,
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 18),
              _TournamentSectionHeader(
                title: tr('Избранные соревнования', 'Favorite competitions'),
                count: favorites.length,
              ),
              const SizedBox(height: 10),
              if (favorites.isEmpty)
                _TournamentEmptyState(
                  message: tr(
                    'Добавьте турниры в избранное через звезду справа.',
                    'Add tournaments to favorites using the star on the right.',
                  ),
                )
              else
                ...favorites.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TournamentListTile(
                      item: item,
                      isFavorite: _favoriteIds.contains(item.id),
                      onToggleFavorite: () => _toggleFavorite(item.id),
                      onTap: () => _openTournament(item),
                    ),
                  ),
                ),
              const SizedBox(height: 18),
              _TournamentSectionHeader(
                title: tr('Все соревнования', 'All competitions'),
                count: filteredTournaments.length,
              ),
              const SizedBox(height: 10),
              if (filteredTournaments.isEmpty)
                _TournamentEmptyState(
                  message: tr(
                    'По вашему запросу турниры не найдены.',
                    'No tournaments matched your search.',
                  ),
                )
              else
                ...groupedLetters.map(
                  (letter) => Padding(
                    key: _letterKeys[letter],
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 8),
                          child: Text(
                            letter,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFACC15),
                              letterSpacing: 1.1,
                            ),
                          ),
                        ),
                        ...filteredTournaments
                            .where((item) => item.firstLetter == letter)
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _TournamentListTile(
                                  item: item,
                                  isFavorite: _favoriteIds.contains(item.id),
                                  onToggleFavorite: () =>
                                      _toggleFavorite(item.id),
                                  onTap: () => _openTournament(item),
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          top: 8,
          right: 0,
          bottom: 0,
          child: Column(
            children: _alphabet.map((letter) {
              final active = groupedLetters.contains(letter);
              return Expanded(
                child: GestureDetector(
                  onTap: active ? () => _jumpToLetter(letter) : null,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 26,
                    child: Center(
                      child: Text(
                        letter,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: active
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: active
                              ? Colors.white.withOpacity(0.82)
                              : Colors.white.withOpacity(0.22),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _TournamentSearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _TournamentSearchField({
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(color: Colors.white),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.white.withOpacity(0.68),
          ),
          hintText: tr(
            'Поиск по стране или турниру',
            'Search by country or tournament',
          ),
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.42),
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _TournamentSectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _TournamentSectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.74),
            ),
          ),
        ),
      ],
    );
  }
}

class _TournamentListTile extends StatelessWidget {
  final TournamentItem item;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTap;

  const _TournamentListTile({
    required this.item,
    required this.isFavorite,
    required this.onToggleFavorite,
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
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(item.flag, style: const TextStyle(fontSize: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.country,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.48),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onToggleFavorite,
                  splashRadius: 20,
                  icon: Icon(
                    isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: isFavorite
                        ? const Color(0xFFFACC15)
                        : Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TournamentEmptyState extends StatelessWidget {
  final String message;

  const _TournamentEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: Colors.white.withOpacity(0.72),
          height: 1.45,
        ),
      ),
    );
  }
}

class TournamentDetailsScreen extends StatelessWidget {
  final TournamentItem tournament;

  const TournamentDetailsScreen({super.key, required this.tournament});

  List<_TournamentMockMatch> get _matches => [
    _TournamentMockMatch(
      stage: '1 тур',
      kickoff: 'Сегодня • 19:00',
      homeTeam: '${tournament.name} XI',
      awayTeam: 'Sportsense FC',
    ),
    _TournamentMockMatch(
      stage: '1 тур',
      kickoff: 'Сегодня • 21:30',
      homeTeam: 'North Stars',
      awayTeam: tournament.country,
    ),
    _TournamentMockMatch(
      stage: '2 тур',
      kickoff: 'Завтра • 20:00',
      homeTeam: 'Union Club',
      awayTeam: 'Blue Horizon',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: SpaceBackground(
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                              ),
                            ),
                            child: IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  tournament.country,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.white.withOpacity(0.56),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${tournament.flag} ${tournament.name}',
                                  style: GoogleFonts.spaceGrotesk(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: TabBar(
                          indicator: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          indicatorPadding: const EdgeInsets.all(6),
                          labelColor: Colors.white,
                          unselectedLabelColor: Colors.white.withOpacity(0.58),
                          labelStyle: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                          dividerColor: Colors.transparent,
                          tabs: const [
                            Tab(text: 'Матчи'),
                            Tab(text: 'Таблица'),
                            Tab(text: 'Новости'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: TabBarView(
                    children: [
                      _TournamentMatchesTabContent(
                        tournament: tournament,
                        mockMatches: _matches,
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: [
                          _TournamentInfoPanel(
                            title: 'Таблица турнира',
                            child: Column(
                              children: const [
                                _TournamentStandingRow(
                                  rank: '1',
                                  team: 'Sportsense FC',
                                  points: '9',
                                ),
                                _TournamentStandingRow(
                                  rank: '2',
                                  team: 'North Stars',
                                  points: '6',
                                ),
                                _TournamentStandingRow(
                                  rank: '3',
                                  team: 'Union Club',
                                  points: '3',
                                ),
                                _TournamentStandingRow(
                                  rank: '4',
                                  team: 'Blue Horizon',
                                  points: '1',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      ListView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        children: const [
                          _TournamentInfoPanel(
                            title: 'Новости турнира',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _TournamentNewsItem(
                                  title:
                                      'Фавориты удерживают темп в верхней части таблицы.',
                                ),
                                _TournamentNewsItem(
                                  title:
                                      'Ключевой матч следующего тура может изменить расстановку лидеров.',
                                ),
                                _TournamentNewsItem(
                                  title:
                                      'Молодые игроки становятся заметным фактором в текущем розыгрыше.',
                                ),
                              ],
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
      ),
    );
  }
}

class _TournamentMatchesTabContent extends StatefulWidget {
  final TournamentItem tournament;
  final List<_TournamentMockMatch> mockMatches;

  const _TournamentMatchesTabContent({
    required this.tournament,
    required this.mockMatches,
  });

  @override
  State<_TournamentMatchesTabContent> createState() =>
      _TournamentMatchesTabContentState();
}

class _TournamentMatchesTabContentState
    extends State<_TournamentMatchesTabContent> {
  final MatchesService _matchesService = MatchesService();
  late Future<List<FootballMatch>>? _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = widget.tournament.leagueId == null
        ? null
        : _matchesService.getMatchesByLeague(
            leagueId: widget.tournament.leagueId!,
            season: widget.tournament.season ?? 2025,
          );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tournament.leagueId == null) {
      if (widget.mockMatches.isEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: const [
            _TournamentInfoPanel(
              title: 'Матчи турнира',
              child: Text(
                'Для этого турнира пока нет подключенного leagueId.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        );
      }

      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: widget.mockMatches.length,
        itemBuilder: (context, index) {
          final match = widget.mockMatches[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TournamentMatchCard(match: match),
          );
        },
      );
    }

    return FutureBuilder<List<FootballMatch>>(
      future: _matchesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: const [_MatchesLoadingState()],
          );
        }

        if (snapshot.hasError) {
          final message = snapshot.error is ApiFootballException
              ? (snapshot.error as ApiFootballException).message
              : 'Не удалось загрузить матчи турнира.';
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _TournamentInfoPanel(
                title: 'Матчи турнира',
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.78),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          );
        }

        final matches = snapshot.data ?? const <FootballMatch>[];
        if (matches.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              _TournamentInfoPanel(
                title: 'Матчи турнира',
                child: Text(
                  'Для сезона ${widget.tournament.season ?? 2025} матчей не найдено.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.78),
                    height: 1.45,
                  ),
                ),
              ),
            ],
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          itemCount: matches.length,
          itemBuilder: (context, index) {
            final match = matches[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _TournamentFootballMatchCard(match: match),
            );
          },
        );
      },
    );
  }
}

class _TournamentMockMatch {
  final String stage;
  final String kickoff;
  final String homeTeam;
  final String awayTeam;

  const _TournamentMockMatch({
    required this.stage,
    required this.kickoff,
    required this.homeTeam,
    required this.awayTeam,
  });
}

class _TournamentMatchCard extends StatelessWidget {
  final _TournamentMockMatch match;

  const _TournamentMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${match.stage} • ${match.kickoff}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.56),
            ),
          ),
          const SizedBox(height: 12),
          _TournamentTeamRow(name: match.homeTeam),
          Divider(color: Colors.white.withOpacity(0.08), height: 20),
          _TournamentTeamRow(name: match.awayTeam),
        ],
      ),
    );
  }
}

class _TournamentFootballMatchCard extends StatelessWidget {
  final FootballMatch match;

  const _TournamentFootballMatchCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final scoreAvailable = match.homeScore != null && match.awayScore != null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatTournamentMeta(match),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white.withOpacity(0.56),
            ),
          ),
          const SizedBox(height: 12),
          _LiveTeamRow(
            name: match.homeTeam,
            badgeUrl: match.homeLogo,
            trailing: scoreAvailable ? '${match.homeScore}' : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _LiveTeamRow(
            name: match.awayTeam,
            badgeUrl: match.awayLogo,
            trailing: scoreAvailable ? '${match.awayScore}' : null,
          ),
        ],
      ),
    );
  }

  String _formatTournamentMeta(FootballMatch match) {
    if (match.isLive) {
      final elapsed = match.elapsed != null ? "${match.elapsed}'" : 'LIVE';
      final short = match.statusShort.isNotEmpty ? match.statusShort : 'LIVE';
      return '$elapsed • $short';
    }
    final hour = match.startTime.hour.toString().padLeft(2, '0');
    final minute = match.startTime.minute.toString().padLeft(2, '0');
    if (match.statusShort == 'NS' || match.statusShort.isEmpty) {
      return '${match.country} • $hour:$minute';
    }
    return '${match.country} • ${match.statusLong}';
  }
}

class _TournamentTeamRow extends StatelessWidget {
  final String name;

  const _TournamentTeamRow({required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            name,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        Text(
          'vs',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.42),
          ),
        ),
      ],
    );
  }
}

class _TournamentInfoPanel extends StatelessWidget {
  final String title;
  final Widget child;

  const _TournamentInfoPanel({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TournamentStandingRow extends StatelessWidget {
  final String rank;
  final String team;
  final String points;

  const _TournamentStandingRow({
    required this.rank,
    required this.team,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              rank,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFFACC15),
              ),
            ),
          ),
          Expanded(
            child: Text(
              team,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          Text(
            points,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.74),
            ),
          ),
        ],
      ),
    );
  }
}

class _TournamentNewsItem extends StatelessWidget {
  final String title;

  const _TournamentNewsItem({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 14,
            height: 1.45,
            color: Colors.white.withOpacity(0.82),
          ),
        ),
      ),
    );
  }
}

class _SavedTab extends StatefulWidget {
  final void Function({String? draft}) onOpenAssistant;

  const _SavedTab({required this.onOpenAssistant});

  @override
  State<_SavedTab> createState() => _SavedTabState();
}

class _SavedTabState extends State<_SavedTab> {
  final DatabaseService _db = DatabaseService();
  List<SavedItem> _savedItems = [];
  bool _isLoading = true;
  User? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadSavedItems();
  }

  Future<void> _loadSavedItems() async {
    try {
      setState(() {
        _isLoading = true;
      });

      _currentUser = await _db.getCurrentUser();

      if (_currentUser != null) {
        final items = await _db.getUserSavedItems(_currentUser!.id!);
        if (mounted) {
          setState(() {
            _savedItems = items;
          });
        }
      }
    } catch (e) {
      print('Ошибка загрузки сохраненных элементов: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'club':
        return Icons.shield_rounded;
      case 'player':
        return Icons.person_rounded;
      case 'monitor':
        return Icons.query_stats_rounded;
      case 'match':
        return Icons.sports_soccer_rounded;
      default:
        return Icons.bookmark_rounded;
    }
  }

  Future<void> _deleteItem(SavedItem item) async {
    try {
      await _db.deleteSavedItem(item.id!);
      await _loadSavedItems();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.title} удален из сохраненных')),
        );
      }
    } catch (e) {
      print('Ошибка удаления: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
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
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator(color: Colors.white)),
        ],
      );
    }

    if (_currentUser == null) {
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
              'Войдите в аккаунт, чтобы сохранять клубы, игроков и мониторинги.',
              'Sign in to save clubs, players and monitors.',
            ),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.68),
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Icon(
              Icons.bookmark_border_rounded,
              size: 64,
              color: Colors.white.withOpacity(0.3),
            ),
          ),
        ],
      );
    }

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
        if (_savedItems.isEmpty)
          Center(
            child: Column(
              children: [
                const SizedBox(height: 32),
                Icon(
                  Icons.bookmark_border_rounded,
                  size: 64,
                  color: Colors.white.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('Пока ничего не сохранено', 'Nothing saved yet'),
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tr(
                    'Сохраняйте клубы, игроков и мониторинги для быстрого доступа',
                    'Save clubs, players and monitors for quick access',
                  ),
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ..._savedItems.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SavedItemTile(
                item: item,
                icon: _getIconForType(item.type),
                onTap: () => widget.onOpenAssistant(
                  draft: 'Подготовь обновленную сводку по ${item.title}',
                ),
                onDelete: () => _deleteItem(item),
              ),
            ),
          ),
        _SectionPanel(
          title: tr('Быстрые действия', 'Quick Actions'),
          subtitle: tr(
            'Используйте сохраненные элементы как отправные точки для анализа',
            'Use saved items as starting points for analysis',
          ),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _GhostButton(
                label: tr('Сводка по клубу', 'Club form brief'),
                icon: Icons.article_rounded,
                onTap: () => widget.onOpenAssistant(
                  draft: 'Сделай сводку по текущей форме сохраненного клуба',
                ),
              ),
              _GhostButton(
                label: tr('Прогноз игрока', 'Player outlook'),
                icon: Icons.radar_rounded,
                onTap: () => widget.onOpenAssistant(
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
            color: selected ? Colors.white : Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? Colors.white : Colors.white.withOpacity(0.08),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? const Color(0xFF102A43) : Colors.white,
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

class _LeagueMatchesSection extends StatelessWidget {
  final String title;
  final String country;
  final List<Widget> children;

  const _LeagueMatchesSection({
    required this.title,
    required this.country,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          country,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: Colors.white.withOpacity(0.56),
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _LiveMatchCard extends StatelessWidget {
  final FootballMatch match;
  final VoidCallback onPreview;

  const _LiveMatchCard({required this.match, required this.onPreview});

  @override
  Widget build(BuildContext context) {
    final scoreAvailable = match.homeScore != null && match.awayScore != null;

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
                  match.country,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF7DD3FC),
                  ),
                ),
              ),
              Text(
                _formatMatchMeta(match),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
            ],
          ),
          if (match.statusLong.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              match.statusLong,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: Colors.white.withOpacity(0.58),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _LiveTeamRow(
            name: match.homeTeam,
            badgeUrl: match.homeLogo,
            trailing: scoreAvailable ? '${match.homeScore}' : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(color: Colors.white24, height: 1),
          ),
          _LiveTeamRow(
            name: match.awayTeam,
            badgeUrl: match.awayLogo,
            trailing: scoreAvailable ? '${match.awayScore}' : null,
          ),
          const SizedBox(height: 14),
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

  String _formatMatchMeta(FootballMatch match) {
    if (match.isLive) {
      final elapsed = match.elapsed != null ? "${match.elapsed}'" : 'LIVE';
      final short = match.statusShort.isNotEmpty ? match.statusShort : 'LIVE';
      return '$elapsed • $short';
    }

    if (match.statusShort == 'NS' || match.statusShort.isEmpty) {
      return _formatMatchDateTime(match.startTime);
    }

    return match.statusLong.isNotEmpty
        ? match.statusLong
        : _formatMatchDateTime(match.startTime);
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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

class _SavedItemTile extends StatelessWidget {
  final SavedItem item;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SavedItemTile({
    required this.item,
    required this.icon,
    required this.onTap,
    required this.onDelete,
  });

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
                child: Icon(icon, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, color: Colors.white54),
                onPressed: onDelete,
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
    print('❌ Ошибка инициализации: $e\n$stackTrace');
    return null;
  }
}
