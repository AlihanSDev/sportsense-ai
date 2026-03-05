import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

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

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _cloudController;
  final List<Star> _stars = List.generate(100, (_) => Star());

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _cloudController = AnimationController(
      duration: const Duration(seconds: 20),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _starController.dispose();
    _cloudController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Чёрный фон
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF000000),
                  Color(0xFF0A0A0F),
                  Color(0xFF0F0F1A),
                ],
              ),
            ),
          ),

          // Анимированные звёзды
          AnimatedBuilder(
            animation: _starController,
            builder: (context, child) {
              return CustomPaint(
                painter: StarFieldPainter(
                  stars: _stars,
                  animation: _starController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Анимированные облака/туманности
          AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: NebulaPainter(
                  animation: _cloudController.value,
                ),
                size: Size.infinite,
              );
            },
          ),

          // Контент
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 60),

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
                        fontSize: 52,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 4,
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

                  const SizedBox(height: 12),

                  // Подзаголовок
                  Text(
                    'Welcome to the Future',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: const Color(0xFFB39DDB),
                      letterSpacing: 3,
                      fontWeight: FontWeight.w300,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Стеклянная карточка
                  Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.08),
                          Colors.white.withOpacity(0.02),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF7C4DFF).withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: const Color(0xFF00D4FF).withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Иконка в неоновом стиле
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF00D4FF),
                                Color(0xFF7C4DFF),
                              ],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF7C4DFF).withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.rocket_launch_rounded,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Заголовок с градиентом
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [
                              Color(0xFF00D4FF),
                              Color(0xFFE040FB),
                            ],
                          ).createShader(bounds),
                          child: Text(
                            'Ready to Explore',
                            style: GoogleFonts.poppins(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        Text(
                          'Your journey through the digital universe begins here. Experience the next generation of mobile applications.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: const Color(0xFFB39DDB),
                            height: 1.8,
                            fontWeight: FontWeight.w300,
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Неоновая кнопка
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(Icons.rocket_launch, color: Colors.white),
                                      const SizedBox(width: 12),
                                      const Text('Launching into space... 🚀',
                                          style: TextStyle(fontSize: 16)),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF7C4DFF),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF00D4FF),
                                    Color(0xFF7C4DFF),
                                    Color(0xFFE040FB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF7C4DFF).withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  'Launch Mission',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Класс звезды
class Star {
  final double x;
  final double y;
  final double size;
  final double opacity;
  final double twinkleSpeed;
  final double phase;

  Star()
      : x = math.Random().nextDouble(),
        y = math.Random().nextDouble(),
        size = math.Random().nextDouble() * 2 + 0.5,
        opacity = math.Random().nextDouble() * 0.5 + 0.3,
        twinkleSpeed = math.Random().nextDouble() * 2 + 1,
        phase = math.Random().nextDouble() * 2 * math.pi;
}

// Рисовальщик звёздного поля
class StarFieldPainter extends CustomPainter {
  final List<Star> stars;
  final double animation;

  StarFieldPainter({required this.stars, required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    for (final star in stars) {
      final twinkle = (math.sin(animation * star.twinkleSpeed * 2 * math.pi + star.phase) + 1) / 2;
      final paint = Paint()
        ..color = Colors.white.withOpacity(star.opacity * (0.5 + twinkle * 0.5))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) => true;
}

// Рисовальщик туманностей/облаков
class NebulaPainter extends CustomPainter {
  final double animation;

  NebulaPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Фиолетовое облако
    final purpleGradient = RadialGradient(
      center: Alignment(
        math.sin(animation * 0.5) * 0.3,
        math.cos(animation * 0.3) * 0.3 - 0.3,
      ),
      radius: 0.8,
      colors: [
        const Color(0xFF7C4DFF).withOpacity(0.15),
        Colors.transparent,
      ],
    );

    // Голубое облако
    final blueGradient = RadialGradient(
      center: Alignment(
        math.cos(animation * 0.4) * 0.4 + 0.2,
        math.sin(animation * 0.5) * 0.2 + 0.2,
      ),
      radius: 0.7,
      colors: [
        const Color(0xFF00D4FF).withOpacity(0.1),
        Colors.transparent,
      ],
    );

    // Розовое облако
    final pinkGradient = RadialGradient(
      center: Alignment(
        math.sin(animation * 0.6) * 0.2 - 0.2,
        math.cos(animation * 0.4) * 0.3 + 0.1,
      ),
      radius: 0.6,
      colors: [
        const Color(0xFFE040FB).withOpacity(0.08),
        Colors.transparent,
      ],
    );

    final purpleRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final blueRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final pinkRect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawRect(
      purpleRect,
      Paint()..shader = purpleGradient.createShader(purpleRect),
    );
    canvas.drawRect(
      blueRect,
      Paint()..shader = blueGradient.createShader(blueRect),
    );
    canvas.drawRect(
      pinkRect,
      Paint()..shader = pinkGradient.createShader(pinkRect),
    );
  }

  @override
  bool shouldRepaint(covariant NebulaPainter oldDelegate) => true;
}
