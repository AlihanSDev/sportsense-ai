import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Фон с молочным цветом, синим оттенком и стилизованными сотами
class SpaceBackground extends StatefulWidget {
  final Widget child;

  const SpaceBackground({super.key, required this.child});

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground> with TickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _cloudController;
  late AnimationController _honeycombController;
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

    _honeycombController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _starController.dispose();
    _cloudController.dispose();
    _honeycombController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Молочный фон с синим оттенком
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFF8F9FA), // Молочный цвет сверху
                Color(0xFFE8F0FF), // Светло-синий
                Color(0xFFD6E6FF), // Голубой
              ],
            ),
          ),
        ),

        // Стилизованные соты
        AnimatedBuilder(
          animation: _honeycombController,
          builder: (context, child) {
            return CustomPaint(
              painter: HoneycombPainter(
                animation: _honeycombController.value,
              ),
              size: Size.infinite,
            );
          },
        ),

        // Анимированные звёзды (теперь с более мягкими цветами)
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

        // Анимированные облака/туманности (в новых цветах)
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
        widget.child,
      ],
    );
  }
}

/// Класс звезды
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

/// Рисовальщик звёздного поля
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

/// Рисовальщик туманностей/облаков
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

/// Рисовальщик стилизованных сот
class HoneycombPainter extends CustomPainter {
  final double animation;

  HoneycombPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFFA7C7FF).withOpacity(0.3);

    // Размеры шестиугольника
    final hexSize = 40.0;
    final hexHeight = hexSize * math.sqrt(3);
    final hexWidth = hexSize * 2;
    final horizontalSpacing = hexWidth * 0.75;
    final verticalSpacing = hexHeight;

    // Смещение для анимации
    final xOffset = (animation * 50) % horizontalSpacing;
    final yOffset = (animation * 30) % verticalSpacing;

    for (double y = -verticalSpacing; y < size.height + verticalSpacing; y += verticalSpacing) {
      for (double x = -horizontalSpacing; x < size.width + horizontalSpacing; x += horizontalSpacing) {
        // Смещаем каждую строку
        final adjustedX = x + ((y / verticalSpacing).floor() % 2 == 0 ? 0 : horizontalSpacing / 2);
        
        // Рисуем шестиугольник
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = math.pi / 3 * i;
          final hx = adjustedX + hexSize * math.cos(angle);
          final hy = y + hexSize * math.sin(angle);
          if (i == 0) {
            path.moveTo(hx, hy);
          } else {
            path.lineTo(hx, hy);
          }
        }
        path.close();

        // Анимация прозрачности
        final alpha = 0.1 + 0.2 * math.sin((x + y) * 0.02 + animation * 2);
        paint.color = Color(0xFFA7C7FF).withOpacity(alpha.clamp(0.0, 0.4));
        
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter oldDelegate) => true;
}
