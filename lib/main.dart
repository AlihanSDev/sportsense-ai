import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/huggingface_service.dart';
import 'services/uefa_search_manager.dart';
import 'widgets/space_background.dart';
import 'widgets/chat_interface.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const SpaceApp());
}

class SpaceApp extends StatelessWidget {
  const SpaceApp({super.key});

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
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final HuggingFaceService _hfService;
  late final UefaSearchManager _uefaSearchManager;
  final List<Message> _messageHistory = [];
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Здравствуйте! Я ваш ИИ-ассистент. Чем я могу вам помочь сегодня?',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _hfService = HuggingFaceService(apiKey: dotenv.env['HF_TOKEN'] ?? '');
    _uefaSearchManager = UefaSearchManager();
    _uefaSearchManager.initialize();
    _uefaSearchManager.addListener(_onUefaSearchChanged);
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
    // Проверка на тестовую фразу BANANA-HEY для проверки анимации
    if (text.trim().toUpperCase() == 'BANANA-HEY') {
      // запрашиваем у менеджера именно ключевую фразу
      await _uefaSearchManager.interceptQuery('BANANA-HEY');
      // Ждём завершения поиска (анимация и индикатор ошибки/успеха показывается внутри)
      while (_uefaSearchManager.isSearching) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      // для теста не добавляем никаких сообщений в чат – достаточно увидеть анимацию
      return;
    }

    // Проверка на триггеры UEFA через UefaSearchManager
    final hasUefaTrigger = await _uefaSearchManager.interceptQuery(text);
    
    if (hasUefaTrigger) {
      // Ждём пока анимация не завершится
      while (_uefaSearchManager.isSearching) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _messageHistory.add(Message(role: 'user', content: text));
      _isLoading = true;
    });

    try {
      final response = await _hfService.chatWithHistory(_messageHistory);
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(text: response, isUser: false));
          _messageHistory.add(Message(role: 'assistant', content: response));
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'Ошибка: $e',
            isUser: false,
          ));
          _isLoading = false;
        });
      }
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
