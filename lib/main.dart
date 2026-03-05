import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/space_background.dart';
import 'widgets/chat_interface.dart';

void main() {
  runApp(const SpaceApp());
}

class SpaceApp extends StatelessWidget {
  const SpaceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TEST APP',
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
  final List<ChatMessage> _messages = [
    ChatMessage(
      text: 'Hello! I\'m your AI assistant. How can I help you today?',
      isUser: false,
    ),
  ];
  bool _isLoading = false;

  void _sendMessage(String text) {
    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isLoading = true;
    });

    // Имитация ответа AI (здесь будет интеграция с вашим сервисом)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            text: 'This is a demo response. Integrate your AI service to get real responses!',
            isUser: false,
          ));
          _isLoading = false;
        });
      }
    });
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
                'TEST APP',
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
