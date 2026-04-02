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
      animation: themeNotifier,
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
    final statusItems = [
      _StatusItem(
        label: 'UEFA rankings',
        value: rankingsApiAvailable ? 'online' : 'offline',
        active: rankingsApiAvailable,
      ),
      _StatusItem(
        label: 'AI analysis',
        value: qwenAvailable ? 'ready' : 'standby',
        active: qwenAvailable,
      ),
      const _StatusItem(label: 'Mode', value: 'matchday', active: true),
    ];

    final quickActions = [
      _QuickActionData(
        title: 'Club Power Index',
        subtitle: 'Track form, ranking shifts and season momentum.',
        icon: Icons.stacked_line_chart_rounded,
        colors: const [Color(0xFF1746A2), Color(0xFF5F9DF7)],
        onTap: () => _openAssistant(
          context,
          draft: 'Покажи ключевые изменения в рейтингах UEFA за последний период',
        ),
      ),
      _QuickActionData(
        title: 'Team Comparison',
        subtitle: 'Compare two clubs before a decisive fixture.',
        icon: Icons.compare_arrows_rounded,
        colors: const [Color(0xFF0F766E), Color(0xFF34D399)],
        onTap: () => _openAssistant(
          context,
          draft: 'Сравни две команды по силе и текущему положению в рейтингах UEFA',
        ),
      ),
      _QuickActionData(
        title: 'Player Radar',
        subtitle: 'Open a concise scouting-style briefing.',
        icon: Icons.radar_rounded,
        colors: const [Color(0xFF9A3412), Color(0xFFF59E0B)],
        onTap: () => _openAssistant(
          context,
          draft: 'Сделай краткий аналитический профиль игрока и его сильных сторон',
        ),
      ),
    ];

    final insightCards = [
      const _InsightCardData(
        eyebrow: 'Focus',
        title: 'Pre-match briefings',
        description: 'Short matchday summaries for clubs, players and UEFA context.',
      ),
      const _InsightCardData(
        eyebrow: 'Workflow',
        title: 'Scenario planning',
        description: 'Use prepared entry points instead of starting from an empty chat.',
      ),
      const _InsightCardData(
        eyebrow: 'Benefit',
        title: 'Faster decisions',
        description: 'The product now feels closer to a sports intelligence hub than a bot.',
      ),
    ];

    return Scaffold(
      body: SpaceBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
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
                            'Football intelligence workspace for fans, analysts and matchday decisions.',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.72),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.tune_rounded, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'MATCHDAY HUB',
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
                        'Start from live football scenarios, not from an empty bot conversation.',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Explore rankings, compare teams and open AI analysis only when it helps the flow.',
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
                            label: 'Open Analysis Center',
                            icon: Icons.north_east_rounded,
                            onTap: () => _openAssistant(context),
                          ),
                          _GhostButton(
                            label: 'UEFA Snapshot',
                            icon: Icons.insights_rounded,
                            onTap: () => _openAssistant(
                              context,
                              draft: 'Дай краткую сводку по текущему состоянию рейтингов UEFA',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: statusItems
                      .map((item) => _StatusPill(item: item))
                      .toList(),
                ),
                const SizedBox(height: 28),
                Text(
                  'Quick actions',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Entry points that feel like product features instead of chat prompts.',
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
                Container(
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
                        'Inside Sportsense',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ...insightCards.map(
                        (card) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _InsightCard(card: card),
                        ),
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

  List<ChatSession> _chats = [];
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
            'Добро пожаловать в Analysis Center.\n\nВыберите готовый сценарий или задайте вопрос по клубам, игрокам и рейтингам UEFA.',
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
          title: 'Чат ${_chats.length + 1}',
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
                  _isLoggedIn ? _username : 'Гость',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _isLoggedIn ? 'Аккаунт активен' : 'Не авторизован',
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
              'Чаты',
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
              "Новый чат",
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
            ),
            onTap: _createNewChat,
          ),
          const Divider(),
          if (!_isLoggedIn)
            ListTile(
              leading: const Icon(Icons.app_registration, color: Colors.blue),
              title: const Text(
                "Регистрация / Вход",
                style: TextStyle(color: Colors.blue),
              ),
              onTap: _showRegistrationDialog,
            ),
          if (_isLoggedIn)
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Выйти", style: TextStyle(color: Colors.red)),
              onTap: _logout,
            ),
          ListTile(
            leading: Icon(
              Icons.settings,
              color: isDark ? Colors.white : Colors.black,
            ),
            title: Text(
              "Настройки",
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
                ],
              ),
              const SizedBox(height: 10),
              // Логотип (белый цвет)
              Column(
                children: [
                  Text(
                    'Analysis Center',
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
                      'ON-DEMAND ANALYSIS',
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
                        label: 'UEFA snapshot',
                        onTap: () => _controller.text =
                            'Дай краткую сводку по текущему состоянию рейтингов UEFA',
                      ),
                      _PromptChip(
                        label: 'Compare clubs',
                        onTap: () => _controller.text =
                            'Сравни две команды по форме и силе в рейтинге UEFA',
                      ),
                      _PromptChip(
                        label: 'Player brief',
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
                        decoration: const InputDecoration(
                          hintText: "Введите запрос для аналитики",
                          hintStyle: TextStyle(color: Colors.white54),
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
      appBar: AppBar(title: const Text("Настройки")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Тёмная тема"),
            value: themeNotifier.isDark,
            onChanged: (_) => themeNotifier.toggle(),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("О приложении"),
            subtitle: const Text("Версия 1.0.0"),
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
