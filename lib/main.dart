import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ======================= СЕРВИСЫ =======================
import 'services/uefa_search_manager.dart';
import 'services/vector_db_manager.dart';
import 'services/user_query_vectorizer.dart';
import 'services/rankings_relevance_service.dart';
import 'services/uefa_parser.dart';
import 'services/qwen_api_service.dart';
import 'services/rankings_vector_search.dart';
import 'services/uefa_rankings_api_service.dart';
import 'services/matches_service.dart';

// ======================= ВИДЖЕТЫ =======================
import 'widgets/space_background.dart';

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
class ThemeNotifier extends ChangeNotifier {
  bool _isDark = true;
  bool get isDark => _isDark;
  ThemeMode get mode => _isDark ? ThemeMode.dark : ThemeMode.light;

  void toggle() {
    _isDark = !_isDark;
    notifyListeners();
  }
}

final themeNotifier = ThemeNotifier();

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

// ======================= MODELS =======================
class ChatMessage {
  final String text;
  final bool isUser;
  final Color? textColor;
  ChatMessage({required this.text, required this.isUser, this.textColor});
}

// ======================= MAIN =======================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      themeMode: themeNotifier.mode,
      theme: ThemeData.light().copyWith(scaffoldBackgroundColor: Colors.white),
      darkTheme: ThemeData.dark(),
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
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: _BottomDock(
          items: navItems,
          selectedIndex: _selectedTab,
          onSelect: (index) => setState(() => _selectedTab = index),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
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
                  color: Colors.white,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitles[_selectedTab],
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.72),
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
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.tune_rounded, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(List<_StatusItem> statusItems) {
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
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF102A43), Color(0xFF1E5F74), Color(0xFF3BA99C)],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3BA99C).withOpacity(0.18),
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
              color: Colors.white.withOpacity(0.14),
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

  final List<ChatSession> _chats = [];
  int _currentChatIndex = 0;
  bool _isLoggedIn = false;
  String _username = '';

  ChatSession get currentChat => _chats[_currentChatIndex];

  @override
  void initState() {
    super.initState();
    _uefaSearchManager = UefaSearchManager();
    _uefaSearchManager.initialize();
    _uefaSearchManager.addListener(_onUefaSearchChanged);

    _createNewChat();

    currentChat.messages.add(
      ChatMessage(
        text:
            tr(
              'Добро пожаловать в Analysis Center.\n\nВыберите готовый сценарий или задайте вопрос по клубам, игрокам и рейтингам UEFA.',
              'Welcome to Analysis Center.\n\nChoose a prepared scenario or ask about clubs, players, and UEFA rankings.',
            ),
        isUser: false,
      ),
    );

    if (widget.initialDraft != null && widget.initialDraft!.trim().isNotEmpty) {
      _controller.text = widget.initialDraft!;
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
    setState(() {
        _chats.add(
          ChatSession(
            id: DateTime.now().toString(),
            title: '${tr('Чат', 'Chat')} ${_chats.length + 1}',
            messages: [],
          ),
        );
      _currentChatIndex = _chats.length - 1;
    });
  }

  void _switchChat(int index) {
    setState(() {
      _currentChatIndex = index;
    });
    Navigator.pop(context);
  }

  void _showRegistrationDialog() {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          title: Text(
            _isLoggedIn ? 'Войти' : 'Регистрация',
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isLoggedIn)
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Имя',
                      hintText: 'Введите ваше имя',
                    ),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'example@mail.com',
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Пароль',
                    hintText: 'Введите пароль',
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  obscureText: true,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                if (_isLoggedIn) {
                  // Логика входа
                  if (emailController.text.isNotEmpty &&
                      passwordController.text.isNotEmpty) {
                    setState(() {
                      _username = emailController.text.split('@')[0];
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Вход выполнен успешно!')),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Пожалуйста, заполните все поля'),
                      ),
                    );
                  }
                } else {
                  // Логика регистрации
                  if (nameController.text.isNotEmpty &&
                      emailController.text.isNotEmpty &&
                      passwordController.text.isNotEmpty) {
                    setState(() {
                      _username = nameController.text;
                      _isLoggedIn = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Добро пожаловать, ${nameController.text}!',
                        ),
                      ),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Пожалуйста, заполните все поля'),
                      ),
                    );
                  }
                }
              },
              child: Text(_isLoggedIn ? 'Войти' : 'Зарегистрироваться'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoggedIn = !_isLoggedIn;
                });
              },
              child: Text(
                _isLoggedIn
                    ? 'Нет аккаунта? Зарегистрироваться'
                    : 'Уже есть аккаунт? Войти',
              ),
            ),
          ],
        );
      },
    );
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
    if (text.isEmpty) return;

    setState(() {
      currentChat.messages.add(ChatMessage(text: text, isUser: true));
    });

    final relevance = RankingsRelevanceService.checkRelevance(text);
    final textColor = RankingsRelevanceService.getRelevanceColor(relevance);

    String ragContext = '';

    if (relevance >= 2.0) {
      await widget.uefaParser.parseAndSaveRankings();
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (relevance >= 1.0) {
      ragContext = await widget.rankingsSearch.getRagContext(text, limit: 10);
    }

    String botResponse;
    if (widget.qwenAvailable) {
      final qwenResponse = await widget.qwenApi.chat(
        text,
        context: ragContext.isNotEmpty ? ragContext : null,
        maxTokens: 1024,
      );
      botResponse =
          qwenResponse?.response ?? 'Произошла ошибка при обработке запроса. Попробуйте ещё раз.';
    } else {
      botResponse = 'Спасибо за вопрос! В данный момент я готовлю ответ по вашему запросу: "$text"';
      if (ragContext.isNotEmpty) botResponse += '\n\n$ragContext';
    }

    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() {
        currentChat.messages.add(
          ChatMessage(text: botResponse, isUser: false, textColor: textColor),
        );
      });
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildDrawer(),
      body: SpaceBackground(
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 10),
              Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      icon: Icon(Icons.menu, color: Colors.white),
                      onPressed: () => Scaffold.of(context).openDrawer(),
                    ),
                  ),
                  const Spacer(),
                  const _LanguageToggle(),
                ],
              ),
              const SizedBox(height: 10),
              // Логотип (белый цвет)
              Column(
                children: [
                  Text(
                    tr('Центр анализа', 'Analysis Center'),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.6,
                      decoration: TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF14B8A6)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      tr('АНАЛИТИКА ПО ЗАПРОСУ', 'ON-DEMAND ANALYSIS'),
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: ScrollController(),
                  itemCount: currentChat.messages.length,
                  itemBuilder: (context, index) {
                    final msg = currentChat.messages[index];
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
              Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: tr(
                            'Введите запрос для аналитики',
                            'Enter an analysis request',
                          ),
                          hintStyle: const TextStyle(color: Colors.white54),
                        ),
                        style: const TextStyle(color: Colors.white),
                        onSubmitted: (_) => _sendMessage(_controller.text),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.white),
                      onPressed: () => _sendMessage(_controller.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
        children: [
          SwitchListTile(
            title: Text(tr('Тёмная тема', 'Dark theme')),
            value: themeNotifier.isDark,
            onChanged: (_) => themeNotifier.toggle(),
          ),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
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

  const _BottomDock({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.4),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final selected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.icon,
                      color: selected
                          ? Colors.white
                          : Colors.white.withOpacity(0.55),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? Colors.white
                            : Colors.white.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
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
  late Future<List<MatchItem>> _matchesFuture;

  @override
  void initState() {
    super.initState();
    _matchesFuture = MatchesService().fetchMatches();
  }

  Future<void> _refresh() async {
    setState(() {
      _matchesFuture = MatchesService().fetchMatches();
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
        FutureBuilder<List<MatchItem>>(
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

            final matches = snapshot.data ?? const [];
            if (matches.isEmpty) {
              return _SectionPanel(
                title: tr('Матчей не найдено', 'No matches found'),
                subtitle: tr(
                  'На сегодня и завтра в выбранных турнирах нет событий.',
                  'No events were found for today and tomorrow in the selected competitions.',
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

            return Column(
              children: matches
                  .map(
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
                  )
                  .toList(),
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
