import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

// ======================= СЕРВИСЫ =======================
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
  
  // Инициализация базы данных
  initDatabase();

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
  final DatabaseService _db = DatabaseService();

  final List<ChatSession> _chats = [];
  int _currentChatIndex = 0;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  User? _currentUser;
  String _username = '';
  bool _isInitializing = true;  // Флаг инициализации

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
            text: 'Здравствуйте! Я ваш ассистент Sportsense. Чем я могу вам помочь сегодня?',
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
    if (text.isEmpty || _chats.isEmpty) return;

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
      _isLoading = true;
    });

    final relevance = RankingsRelevanceService.checkRelevance(text);
    final textColor = RankingsRelevanceService.getRelevanceColor(relevance);

    String ragContext = '';
    String? parsingStatus;

    if (relevance >= 2.0) {
      parsingStatus = '🔄 RAG: Парсинг UEFA Rankings...';
      await widget.uefaParser.parseAndSaveRankings();
      await Future.delayed(const Duration(milliseconds: 500));
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
          qwenResponse?.response ?? '❌ Ошибка при получении ответа от Qwen.';
    } else {
      botResponse = '**Тестовый режим**\n';
      if (ragContext.isNotEmpty) botResponse += '$ragContext\n';
      botResponse += 'Ваш запрос: "$text"';
    }

    String fullResponse =
        (parsingStatus != null ? '$parsingStatus\n\n' : '') + botResponse;

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted && _chats.isNotEmpty) {
      setState(() {
        currentChat.messages.add(
          ChatMessage(text: fullResponse, isUser: false, textColor: textColor),
        );
        _isLoading = false;
      });

      // Сохраняем ответ бота в SQLite
      if (_isLoggedIn && _currentUser != null && currentChat.id != null && currentChat.id != '0') {
        final chatId = int.parse(currentChat.id!);
        _db.addMessage(
          chatId: chatId,
          text: fullResponse,
          isUser: false,
        ).catchError((e) {
          print('Ошибка сохранения ответа: $e');
          return null;
        });
      }
    }

    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text("Настройки")),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Тёмная тема"),
            value: themeNotifier.isDark,
            onChanged: (_) => themeNotifier.toggle(),
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
