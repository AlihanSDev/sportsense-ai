import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Адаптивный фон: тёмный космический / светлый молочный / Sportsense (тёмный + соты)
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
  late AnimationController _honeycombController;
  final List<Star> _stars = List.generate(80, (_) => Star());

  @override
  void initState() {
    super.initState();
    _starController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);

    _cloudController = AnimationController(
      duration: const Duration(seconds: 30),
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
    final brightness = Theme.of(context).brightness;
    final isLight = brightness == Brightness.light;
    // Sportsense = тёмный фон + соты (геометрические детали светлой темы)
    final isSportsense = !isLight;

    return Stack(
      children: [
        // Фон: тёмный космический или светлый молочный
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: isLight
                  ? const [
                      Color(0xFFF8F9FA), // молочный
                      Color(0xFFE8F0FF), // светло-синий
                      Color(0xFFD6E6FF), // голубой
                    ]
                  : const [
                      Color(0xFF0B0B12), // глубокий тёмно-синий
                      Color(0xFF14141F), // мягкий фиолетово-серый
                      Color(0xFF1A1A26), // тёплый тёмно-серый
                    ],
            ),
          ),
        ),

        // Звёзды: всегда на тёмном фоне
        if (!isLight)
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

        // Мягкие облака: только для чистой тёмной темы (без сот)
        if (!isLight && !isSportsense)
          AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: CloudPainter(animation: _cloudController.value),
                size: Size.infinite,
              );
            },
          ),

        // Соты: светлая тема ИЛИ Sportsense (тёмный + геометрия)
        if (!isLight || isSportsense)
          AnimatedBuilder(
            animation: _honeycombController,
            builder: (context, child) {
              return CustomPaint(
                painter: HoneycombPainter(
                  animation: _honeycombController.value,
                  isDark: !isLight,
                ),
                size: Size.infinite,
              );
            },
          ),

        // Лёгкие туманности для светлой темы
        if (isLight)
          AnimatedBuilder(
            animation: _cloudController,
            builder: (context, child) {
              return CustomPaint(
                painter: LightNebulaPainter(animation: _cloudController.value),
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

// ======================= DARK THEME (оригинал из main) =======================

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
        size = math.Random().nextDouble() * 1.5 + 0.3,
        opacity = math.Random().nextDouble() * 0.4 + 0.2,
        twinkleSpeed = math.Random().nextDouble() * 1.5 + 0.5,
        phase = math.Random().nextDouble() * 2 * math.pi;
}

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

      final paint = Paint()
        ..color = Colors.white.withOpacity(star.opacity * (0.3 + twinkle * 0.3))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0);

      canvas.drawCircle(
        Offset(star.x * size.width, star.y * size.height),
        star.size,
        paint,
      );

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

class CloudPainter extends CustomPainter {
  final double animation;

  CloudPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);

    final purpleGradient = RadialGradient(
      center: Alignment(
        -0.3 + math.sin(animation * 0.2) * 0.1,
        -0.2 + math.cos(animation * 0.15) * 0.1,
      ),
      radius: 0.9,
      colors: [const Color(0xFF8B7DD8).withOpacity(0.08), Colors.transparent],
    );

    final blueGradient = RadialGradient(
      center: Alignment(
        0.4 + math.cos(animation * 0.18) * 0.15,
        0.3 + math.sin(animation * 0.12) * 0.1,
      ),
      radius: 0.8,
      colors: [const Color(0xFF7A9BCB).withOpacity(0.07), Colors.transparent],
    );

    final warmGradient = RadialGradient(
      center: Alignment(
        -0.1 + math.sin(animation * 0.1) * 0.2,
        0.5 + math.cos(animation * 0.1) * 0.2,
      ),
      radius: 1.0,
      colors: [const Color(0xFFB89E97).withOpacity(0.05), Colors.transparent],
    );

    final grayGradient = RadialGradient(
      center: Alignment(
        math.cos(animation * 0.25) * 0.2,
        math.sin(animation * 0.2) * 0.2,
      ),
      radius: 0.7,
      colors: [const Color(0xFFA0A0B0).withOpacity(0.04), Colors.transparent],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawRect(rect, Paint()..shader = purpleGradient.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = blueGradient.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = warmGradient.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = grayGradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant CloudPainter oldDelegate) => true;
}

// ======================= LIGHT THEME (соты + мягкие туманности) =======================

class HoneycombPainter extends CustomPainter {
  final double animation;
  final bool isDark;

  HoneycombPainter({required this.animation, this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.2 : 1.5
      ..color = isDark
          ? const Color(0xFFA7C7FF).withOpacity(0.2)
          : const Color(0xFF4A90E2).withOpacity(0.12);

    final hexSize = 40.0;
    final hexHeight = hexSize * math.sqrt(3);
    final hexWidth = hexSize * 2;
    final horizontalSpacing = hexWidth * 0.75;
    final verticalSpacing = hexHeight;

    for (double y = -verticalSpacing; y < size.height + verticalSpacing; y += verticalSpacing) {
      for (double x = -horizontalSpacing; x < size.width + horizontalSpacing; x += horizontalSpacing) {
        final adjustedX = x + ((y / verticalSpacing).floor() % 2 == 0 ? 0 : horizontalSpacing / 2);

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

        final alpha = isDark
            ? (0.08 + 0.15 * math.sin((x + y) * 0.02 + animation * 2)).clamp(0.0, 0.3)
            : (0.05 + 0.08 * math.sin((x + y) * 0.02 + animation * 2)).clamp(0.0, 0.15);
        paint.color = isDark
            ? Color(0xFFA7C7FF).withOpacity(alpha)
            : Color(0xFF4A90E2).withOpacity(alpha);

        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant HoneycombPainter oldDelegate) => true;
}

class LightNebulaPainter extends CustomPainter {
  final double animation;

  LightNebulaPainter({required this.animation});

  @override
  void paint(Canvas canvas, Size size) {
    final purpleGradient = RadialGradient(
      center: Alignment(
        math.sin(animation * 0.5) * 0.3,
        math.cos(animation * 0.3) * 0.3 - 0.3,
      ),
      radius: 0.8,
      colors: [const Color(0xFF7C4DFF).withOpacity(0.06), Colors.transparent],
    );

    final blueGradient = RadialGradient(
      center: Alignment(
        math.cos(animation * 0.4) * 0.4 + 0.2,
        math.sin(animation * 0.5) * 0.2 + 0.2,
      ),
      radius: 0.7,
      colors: [const Color(0xFF00D4FF).withOpacity(0.04), Colors.transparent],
    );

    final pinkGradient = RadialGradient(
      center: Alignment(
        math.sin(animation * 0.6) * 0.2 - 0.2,
        math.cos(animation * 0.4) * 0.3 + 0.1,
      ),
      radius: 0.6,
      colors: [const Color(0xFFE040FB).withOpacity(0.03), Colors.transparent],
    );

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    canvas.drawRect(rect, Paint()..shader = purpleGradient.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = blueGradient.createShader(rect));
    canvas.drawRect(rect, Paint()..shader = pinkGradient.createShader(rect));
  }

  @override
  bool shouldRepaint(covariant LightNebulaPainter oldDelegate) => true;
}
