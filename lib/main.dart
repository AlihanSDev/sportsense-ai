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
      home: ChatScreen(
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

// ======================= CHAT SCREEN =======================
class ChatScreen extends StatefulWidget {
  final VectorDatabaseManager vectorDbManager;
  final UserQueryVectorizerService queryVectorizer;
  final UefaParser uefaParser;
  final QwenApiService qwenApi;
  final RankingsVectorSearch rankingsSearch;
  final bool rankingsApiAvailable;
  final bool qwenAvailable;

  const ChatScreen({
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
        text: 'Добро пожаловать в Sportsense! 🏆\n\nЗадайте вопрос о футбольных игроках, командах или рейтингах UEFA.',
        isUser: false,
      ),
    );
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
                    'Sportsense',
                    style: GoogleFonts.inter(
                      fontSize: 42,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 2,
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
                        colors: [Color(0xFF4A90E2), Color(0xFF357ABD)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'AI ASSISTANT',
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
                          hintText: "Введите сообщение",
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
