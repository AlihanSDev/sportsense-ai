import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../main.dart' show themeNotifier;

/// Спокойный фон с мягкими облаками и мерцающими звёздами
class SpaceBackground extends StatefulWidget {
  final Widget child;

  const SpaceBackground({super.key, required this.child});

  @override
  State<SpaceBackground> createState() => _SpaceBackgroundState();
}

class _SpaceBackgroundState extends State<SpaceBackground>
    with TickerProviderStateMixin {
  late AnimationController _starController;
  late AnimationController _cloudController;
  final List<Star> _stars = List.generate(80, (_) => Star()); // меньше звёзд

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _cloudController = AnimationController(
      duration: const Duration(seconds: 30), // медленнее
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
    final isDark = themeNotifier.isDark;

    return Stack(
      children: [
        // Градиент фона
        Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0B0B12),
                      Color(0xFF14141F),
                      Color(0xFF1A1A26),
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFE8EEF5),
                      Color(0xFFF0F4F8),
                      Color(0xFFF5F7FA),
                    ],
                  ),
          ),
        ),

        // Мерцающие звёзды (только для тёмной темы)
        if (isDark)
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

        // Мягкие облака
        AnimatedBuilder(
          animation: _cloudController,
          builder: (context, child) {
            return CustomPaint(
              painter: CloudPainter(
                animation: _cloudController.value,
                isDark: isDark,
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
      size = math.Random().nextDouble() * 1.5 + 0.3, // меньше
      opacity = math.Random().nextDouble() * 0.4 + 0.2, // мягче
      twinkleSpeed = math.Random().nextDouble() * 1.5 + 0.5,
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
      final twinkle =
          (math.sin(animation * star.twinkleSpeed * 2 * math.pi + star.phase) +
              1) /
          2;

      // Мягкое свечение
      final paint = Paint()
        ..color = Colors.white.withOpacity(star.opacity * (0.3 + twinkle * 0.3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );

      // Добавляем лёгкое гало для крупных звёзд
      if (star.size > 1.0) {
        final glowPaint = Paint()
          ..color = Colors.white.withOpacity(star.opacity * 0.1 * twinkle)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);

        canvas.drawCircle(
          Offset(star.x * size.width, star.y * size.height),
          star.size * 2,
          glowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarFieldPainter oldDelegate) => true;
}

/// Рисовальщик мягких облаков
class CloudPainter extends CustomPainter {
  final double animation;
  final bool isDark;

  CloudPainter({required this.animation, this.isDark = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    if (isDark) {
      // Мягкое фиолетовое облако (слева)
      final purpleGradient = RadialGradient(
        center: Alignment(
          -0.3 + math.sin(animation * 0.2) * 0.1,
          -0.2 + math.cos(animation * 0.15) * 0.1,
        ),
        radius: 0.9,
        colors: [const Color(0xFF8B7DD8).withOpacity(0.08), Colors.transparent],
      );

      // Мягкое синее облако (справа)
      final blueGradient = RadialGradient(
        center: Alignment(
          0.4 + math.cos(animation * 0.18) * 0.15,
          0.3 + math.sin(animation * 0.12) * 0.1,
        ),
        radius: 0.8,
        colors: [const Color(0xFF7A9BCB).withOpacity(0.07), Colors.transparent],
      );

      // Тёплое облако (снизу)
      final warmGradient = RadialGradient(
        center: Alignment(
          -0.1 + math.sin(animation * 0.1) * 0.2,
          0.5 + math.cos(animation * 0.1) * 0.2,
        ),
        radius: 1.0,
        colors: [const Color(0xFFB89E97).withOpacity(0.05), Colors.transparent],
      );

      // Лёгкое серое облако (центр)
      final grayGradient = RadialGradient(
        center: Alignment(
          math.cos(animation * 0.25) * 0.2,
          math.sin(animation * 0.2) * 0.2,
        ),
        radius: 0.7,
        colors: [const Color(0xFFA0A0B0).withOpacity(0.04), Colors.transparent],
      );

      final rect = Rect.fromLTWH(0, 0, size.width, size.height);

      canvas.drawRect(
        rect,
        Paint()..shader = purpleGradient.createShader(rect),
      );
      canvas.drawRect(rect, Paint()..shader = blueGradient.createShader(rect));
      canvas.drawRect(rect, Paint()..shader = warmGradient.createShader(rect));
      canvas.drawRect(rect, Paint()..shader = grayGradient.createShader(rect));
    } else {
      // Светлые облака для белой темы
      final lightBlueGradient = RadialGradient(
        center: Alignment(
          -0.2 + math.sin(animation * 0.2) * 0.1,
          -0.3 + math.cos(animation * 0.15) * 0.1,
        ),
        radius: 0.9,
        colors: [const Color(0xFFB3D4F0).withOpacity(0.3), Colors.transparent],
      );

      final lightPurpleGradient = RadialGradient(
        center: Alignment(
          0.5 + math.cos(animation * 0.18) * 0.15,
          0.2 + math.sin(animation * 0.12) * 0.1,
        ),
        radius: 0.8,
        colors: [const Color(0xFFD4C4F0).withOpacity(0.25), Colors.transparent],
      );

      final lightWarmGradient = RadialGradient(
        center: Alignment(
          -0.1 + math.sin(animation * 0.1) * 0.2,
          0.6 + math.cos(animation * 0.1) * 0.2,
        ),
        radius: 1.0,
        colors: [const Color(0xFFF0E0D4).withOpacity(0.2), Colors.transparent],
      );

      final rect = Rect.fromLTWH(0, 0, size.width, size.height);

      canvas.drawRect(
        rect,
        Paint()..shader = lightBlueGradient.createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()..shader = lightPurpleGradient.createShader(rect),
      );
      canvas.drawRect(
        rect,
        Paint()..shader = lightWarmGradient.createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CloudPainter oldDelegate) => true;
}
