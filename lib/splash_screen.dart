import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

// ======================= COLORS =======================
const _bg = Color(0xFF060606);
const _fg = Color(0xFFd4d4d4);
const _fgMuted = Color(0xFF444444);
const _fgDim = Color(0xFF222222);
const _accent = Color(0xFF999999);
const _glow = Color(0x0CB4B4B4);

// ======================= PARTICLES =======================
class _Particle {
  double x, y, r, vx, vy, a;
  _Particle({
    required this.x,
    required this.y,
    required this.r,
    required this.vx,
    required this.vy,
    required this.a,
  });
}

class _ParticlesPainter extends CustomPainter {
  final List<_Particle> particles;
  _ParticlesPainter(this.particles);
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()..strokeWidth = 0.5;
    for (final p in particles) {
      canvas.drawCircle(
        Offset(p.x, p.y),
        math.max(0.1, p.r),
        Paint()..color = _fg.withOpacity(p.a),
      );
    }
    const maxD = 110.0;
    for (var i = 0; i < particles.length; i++) {
      for (var j = i + 1; j < particles.length; j++) {
        final dx = particles[i].x - particles[j].x;
        final dy = particles[i].y - particles[j].y;
        final dSq = dx * dx + dy * dy;
        if (dSq < maxD * maxD) {
          final alpha = (1 - math.sqrt(dSq) / maxD) * 0.05;
          linePaint.color = _fg.withOpacity(alpha);
          canvas.drawLine(
            Offset(particles[i].x, particles[i].y),
            Offset(particles[j].x, particles[j].y),
            linePaint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter old) => true;
}

// ======================= NOISE =======================
class _NoisePainter extends CustomPainter {
  final ui.Image? noiseImage;
  _NoisePainter(this.noiseImage);
  @override
  void paint(Canvas canvas, Size size) {
    if (noiseImage != null) {
      final paint = Paint()..color = Colors.white.withOpacity(0.03);
      canvas.drawImageRect(
        noiseImage!,
        Rect.fromLTWH(
          0,
          0,
          noiseImage!.width.toDouble(),
          noiseImage!.height.toDouble(),
        ),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter old) => false;
}

// ======================= FLASH =======================
class _FlashOverlay extends StatelessWidget {
  final bool fire;
  const _FlashOverlay({required this.fire});
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 40),
      opacity: fire ? 1.0 : 0.0,
      child: Container(color: _bg),
    );
  }
}

// ======================= RINGS =======================
class _AnimatedRing extends StatefulWidget {
  final double width, height, top, left, right, bottom;
  final String driftType;
  final bool reverse;
  const _AnimatedRing({
    required this.width,
    required this.height,
    this.top = 0,
    this.left = 0,
    this.right = 0,
    this.bottom = 0,
    required this.driftType,
    this.reverse = false,
  });
  @override
  State<_AnimatedRing> createState() => _AnimatedRingState();
}

class _AnimatedRingState extends State<_AnimatedRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    int seconds;
    switch (widget.driftType) {
      case '1':
        seconds = 14;
        break;
      case '2':
        seconds = 18;
        break;
      case '3':
        seconds = 11;
        break;
      default:
        seconds = 14;
    }
    _ctrl = AnimationController(
      vsync: this,
      duration: Duration(seconds: seconds),
    )..repeat(reverse: widget.reverse);
    _anim = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        Offset offset;
        double rotation = 0;
        switch (widget.driftType) {
          case '1':
            offset = Offset(18 * _anim.value, -24 * _anim.value);
            rotation = 6 * _anim.value;
            break;
          case '2':
            offset = Offset(-14 * _anim.value, 18 * _anim.value);
            break;
          case '3':
            offset = Offset(10 * _anim.value - 5, -14 * _anim.value + 7);
            rotation = 20 * _anim.value - 10;
            break;
          default:
            offset = Offset.zero;
        }
        return Transform.translate(
          offset: offset,
          child: Transform.rotate(
            angle: rotation * math.pi / 180,
            child: Container(
              width: widget.width,
              height: widget.height,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: _fgDim, width: 1),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======================= PULSE DOTS =======================
class _PulseDot extends StatefulWidget {
  final double top, left, right, bottom;
  final int delayMs;
  const _PulseDot({
    this.top = 0,
    this.left = 0,
    this.right = 0,
    this.bottom = 0,
    this.delayMs = 0,
  });
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  bool _started = false;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (widget.delayMs == 0) {
      _startAnimation();
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _startAnimation();
      });
    }
  }

  void _startAnimation() {
    setState(() => _started = true);
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.top == 0 ? null : widget.top,
      left: widget.left == 0 ? null : widget.left,
      right: widget.right == 0 ? null : widget.right,
      bottom: widget.bottom == 0 ? null : widget.bottom,
      child: _started
          ? AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                final scale = 1 + _anim.value * 2;
                final opacity = 0.1 + _anim.value * 0.25;
                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                        color: _fgMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              },
            )
          : const SizedBox.shrink(),
    );
  }
}

// ======================= SCAN LINES =======================
class _ScanLine extends StatefulWidget {
  final int delayMs;
  const _ScanLine({this.delayMs = 0});
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 9000),
    );
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _ctrl.repeat(period: const Duration(milliseconds: 9000));
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final top = -2 + _ctrl.value * MediaQuery.of(context).size.height;
        double opacity;
        if (_ctrl.value < 0.05) {
          opacity = _ctrl.value * 20;
        } else if (_ctrl.value > 0.95) {
          opacity = (1 - _ctrl.value) * 20;
        } else {
          opacity = 1.0;
        }
        return Positioned(
          top: top,
          left: 0,
          right: 0,
          child: Opacity(
            opacity: opacity * 0.025,
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    Colors.white,
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======================= CORNERS =======================
class _CornerMark extends StatelessWidget {
  final double top, left, right, bottom;
  final bool isTL, isTR, isBL, isBR;
  const _CornerMark({
    this.top = 0,
    this.left = 0,
    this.right = 0,
    this.bottom = 0,
    this.isTL = false,
    this.isTR = false,
    this.isBL = false,
    this.isBR = false,
  });
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top == 0 ? null : top,
      left: left == 0 ? null : left,
      right: right == 0 ? null : right,
      bottom: bottom == 0 ? null : bottom,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(
          opacity: value * 0.15,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border(
                top: (isTL || isTR)
                    ? const BorderSide(color: _fgMuted, width: 1)
                    : BorderSide.none,
                left: (isTL || isBL)
                    ? const BorderSide(color: _fgMuted, width: 1)
                    : BorderSide.none,
                right: (isTR || isBR)
                    ? const BorderSide(color: _fgMuted, width: 1)
                    : BorderSide.none,
                bottom: (isBL || isBR)
                    ? const BorderSide(color: _fgMuted, width: 1)
                    : BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ======================= H LINES =======================
class _HLine extends StatelessWidget {
  final bool expanded;
  final bool isBottom;
  const _HLine({required this.expanded, this.isBottom = false});
  @override
  Widget build(BuildContext context) {
    final maxWidth = isBottom
        ? math.min(300.0, MediaQuery.of(context).size.width * 0.6)
        : math.min(460.0, MediaQuery.of(context).size.width * 0.8);
    final bool isClosing = !expanded;
    final duration = isClosing
        ? const Duration(milliseconds: 700)
        : (isBottom
              ? const Duration(milliseconds: 1000)
              : const Duration(milliseconds: 1400));
    final curve = isClosing
        ? const Cubic(0.55, 0.06, 0.68, 0.19)
        : Curves.easeOutCubic;
    return AnimatedContainer(
      duration: duration,
      curve: curve,
      width: expanded ? maxWidth : 0,
      height: 1,
      margin: EdgeInsets.only(
        top: isBottom ? 0 : 52,
        bottom: isBottom ? 52 : 0,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            isBottom ? _fgDim : _fgMuted,
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// ======================= LETTER =======================
class _AnimatedLetter extends StatelessWidget {
  final String letter;
  final bool visible;
  const _AnimatedLetter({required this.letter, required this.visible});
  @override
  Widget build(BuildContext context) {
    final fontSize = math.min(
      76.0,
      math.max(30.0, MediaQuery.of(context).size.width * 0.075),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 550),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (context, value, child) {
        final blurSigma = 8 * (1 - value);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * value,
            child: Opacity(
              opacity: value,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: blurSigma,
                  sigmaY: blurSigma,
                ),
                child: Text(
                  letter,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w300,
                    color: _fg,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ======================= DASH =======================
class _AnimatedDash extends StatelessWidget {
  final bool visible;
  const _AnimatedDash({required this.visible});
  @override
  Widget build(BuildContext context) {
    final fontSize = math.min(
      76.0,
      math.max(30.0, MediaQuery.of(context).size.width * 0.075),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 530),
      curve: const Interval(0.1509, 1.0, curve: Curves.easeOut),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Text(
          '-',
          style: GoogleFonts.spaceGrotesk(
            fontSize: fontSize,
            fontWeight: FontWeight.w200,
            color: _fgMuted,
          ),
        ),
      ),
    );
  }
}

// ======================= AI =======================
class _AnimatedAI extends StatelessWidget {
  final bool visible;
  const _AnimatedAI({required this.visible});
  @override
  Widget build(BuildContext context) {
    final fontSize = math.min(
      76.0,
      math.max(30.0, MediaQuery.of(context).size.width * 0.075),
    );
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: visible ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 750),
      curve: const Cubic(0.16, 1, 0.3, 1),
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, 12 * (1 - value)),
        child: Opacity(
          opacity: value,
          child: Stack(
            children: [
              if (visible)
                Positioned(
                  left: -36,
                  right: -36,
                  top: -24,
                  bottom: -24,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1550),
                    curve: const Interval(0.2258, 1.0, curve: Curves.easeOut),
                    builder: (context, gv, child) => Opacity(
                      opacity: gv,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: RadialGradient(
                            colors: [_glow, Colors.transparent],
                            stops: [0, 0.7],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Text(
                'AI',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w500,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================= SUBTITLE =======================
class _Subtitle extends StatelessWidget {
  final bool visible;
  const _Subtitle({required this.visible});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final fontSize = math.min(13.0, math.max(9.0, width * 0.014));
    final letterSpacing = fontSize * 0.4;
    return AnimatedOpacity(
      opacity: visible ? 0.6 : 0,
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      child: AnimatedTransform(
        visible: visible,
        child: Text(
          'INTELLIGENT SPORTS ANALYTICS',
          style: GoogleFonts.spaceGrotesk(
            fontSize: fontSize,
            fontWeight: FontWeight.w400,
            letterSpacing: letterSpacing,
            color: _fgMuted,
          ),
        ),
      ),
    );
  }
}

// ======================= VERSION =======================
class _VersionLine extends StatelessWidget {
  final bool visible;
  const _VersionLine({required this.visible});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 66,
      bottom: 44,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOut,
        width: visible ? 60 : 0,
        height: 1,
        decoration: const BoxDecoration(color: _fgDim),
      ),
    );
  }
}

class _VersionLabel extends StatelessWidget {
  final bool visible;
  const _VersionLabel({required this.visible});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 40,
      right: 66,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 700),
        opacity: visible ? 0.3 : 0,
        child: Text(
          'v1.0.0',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 10,
            letterSpacing: 2.2,
            color: _fgMuted,
          ),
        ),
      ),
    );
  }
}

// ======================= ANIMATED TRANSFORM =======================
class AnimatedTransform extends StatelessWidget {
  final bool visible;
  final Widget child;
  const AnimatedTransform({
    required this.visible,
    required this.child,
    super.key,
  });
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 900),
      curve: const Cubic(0.16, 1, 0.3, 1),
      transform: Matrix4.translationValues(0, visible ? 0 : 10, 0),
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 900),
        curve: const Cubic(0.16, 1, 0.3, 1),
        child: child,
      ),
    );
  }
}

// ======================= MAIN SPLASH =======================
class SplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  const SplashScreen({this.onComplete, super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  final List<_Particle> _particles = [];
  ui.Image? _noiseImage;
  bool _showFlash = false;
  bool _showDecor = false;
  bool _lineTopExpanded = false;
  bool _lineBottomExpanded = false;
  bool _showDash = false;
  bool _showAI = false;
  bool _showSubtitle = false;
  bool _showVersion = false;
  bool _fadeOut = false;

  final String _text = 'SPORTSENSE';
  final List<bool> _letterVisible = List.filled(10, false);
  late AnimationController _particleCtrl;

  @override
  void initState() {
    super.initState();
    _initParticles();
    _generateNoiseImage();
    // Particle animation loop
    _particleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 16),
    );
    _particleCtrl.addListener(_updateParticles);
    _particleCtrl.repeat();
    _startSequence();
  }

  void _updateParticles() {
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;
      if (p.x < -20) p.x = 1000 + 20;
      if (p.x > 1000 + 20) p.x = -20;
      if (p.y < -20) p.y = 1000 + 20;
      if (p.y > 1000 + 20) p.y = -20;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _particleCtrl.dispose();
    super.dispose();
  }

  void _initParticles() {
    final rng = math.Random();
    for (var i = 0; i < 55; i++) {
      _particles.add(
        _Particle(
          x: rng.nextDouble() * 1000,
          y: rng.nextDouble() * 1000,
          r: rng.nextDouble() * 1.1 + 0.3,
          vx: (rng.nextDouble() - 0.5) * 0.12,
          vy: (rng.nextDouble() - 0.5) * 0.12,
          a: rng.nextDouble() * 0.2 + 0.04,
        ),
      );
    }
  }

  Future<void> _generateNoiseImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = Colors.white;
    final rng = math.Random(42);
    for (var y = 0; y < 128; y++) {
      for (var x = 0; x < 128; x++) {
        final gray = rng.nextDouble() * 255;
        paint.color = Color.fromARGB(
          255,
          gray.toInt(),
          gray.toInt(),
          gray.toInt(),
        );
        canvas.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 1, 1), paint);
      }
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(128, 128);
    if (mounted) setState(() => _noiseImage = image);
  }

  void _startSequence() async {
    const stagger = 75;
    final length = _text.length; // 10

    // Phase 0: Flash (50-180)
    await Future.delayed(const Duration(milliseconds: 50));
    if (!mounted) return;
    setState(() => _showFlash = true);
    await Future.delayed(const Duration(milliseconds: 130));
    if (!mounted) return;
    setState(() => _showFlash = false);

    // Phase 1: Decor (250)
    await Future.delayed(const Duration(milliseconds: 70));
    if (!mounted) return;
    setState(() => _showDecor = true);

    // Phase 2: Top line (450)
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _lineTopExpanded = true);

    // Phase 3: Letters start (800)
    await Future.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;
    setState(() => _letterVisible[0] = true);
    for (int i = 1; i < length; i++) {
      await Future.delayed(const Duration(milliseconds: stagger));
      if (!mounted) return;
      setState(() => _letterVisible[i] = true);
    }
    // Align to afterChars = 800 + length*stagger = 1550
    await Future.delayed(const Duration(milliseconds: stagger));
    // t = 1550

    // Phase 4: Dash at 1670
    await Future.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    setState(() => _showDash = true);

    // Phase 5: AI at 1755
    await Future.delayed(const Duration(milliseconds: 160));
    if (!mounted) return;
    setState(() => _showAI = true);

    // Phase 6: Subtitle at 2075
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    setState(() => _showSubtitle = true);

    // Phase 7: Bottom line at 2275
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _lineBottomExpanded = true);

    // Phase 8: Version at 2525
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;
    setState(() => _showVersion = true);

    // Phase 9: Collapse at 3875
    await Future.delayed(const Duration(milliseconds: 1350));
    if (!mounted) return;
    setState(() {
      _lineTopExpanded = false;
      _lineBottomExpanded = false;
    });

    // Phase 10: Fade out at 4375
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    setState(() => _fadeOut = true);

    // Complete at 5575
    await Future.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    widget.onComplete?.call();
  }

  Widget _buildFadeIn(Widget child) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 2500),
      curve: Curves.ease,
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: _bg),
        if (_particles.isNotEmpty)
          CustomPaint(painter: _ParticlesPainter(_particles)),
        if (_noiseImage != null)
          CustomPaint(painter: _NoisePainter(_noiseImage)),
        _FlashOverlay(fire: _showFlash),
        AnimatedOpacity(
          opacity: _fadeOut ? 0 : 1,
          duration: const Duration(milliseconds: 1200),
          curve: Curves.easeOutCubic,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Rings (5) with fade-in
              if (_showDecor) ...[
                _buildFadeIn(
                  _AnimatedRing(
                    width: 280,
                    height: 280,
                    top: 0.10 * size.height,
                    left: -80,
                    driftType: '1',
                  ),
                ),
                _buildFadeIn(
                  _AnimatedRing(
                    width: 160,
                    height: 160,
                    bottom: 0.15 * size.height,
                    right: -40,
                    driftType: '2',
                  ),
                ),
                _buildFadeIn(
                  _AnimatedRing(
                    width: 80,
                    height: 80,
                    top: 0.22 * size.height,
                    right: 0.12 * size.width,
                    driftType: '3',
                  ),
                ),
                _buildFadeIn(
                  _AnimatedRing(
                    width: 360,
                    height: 360,
                    bottom: -140,
                    left: 0.25 * size.width,
                    driftType: '1',
                    reverse: true,
                  ),
                ),
                _buildFadeIn(
                  _AnimatedRing(
                    width: 40,
                    height: 40,
                    bottom: 0.35 * size.height,
                    left: 0.12 * size.width,
                    driftType: '3',
                  ),
                ),
              ],
              // Dots (6)
              if (_showDecor) ...[
                _PulseDot(top: 0.20 * size.height, left: 0.18 * size.width),
                _PulseDot(
                  top: 0.55 * size.height,
                  right: 0.15 * size.width,
                  delayMs: 1200,
                ),
                _PulseDot(
                  bottom: 0.28 * size.height,
                  left: 0.32 * size.width,
                  delayMs: 2400,
                ),
                _PulseDot(
                  top: 0.14 * size.height,
                  right: 0.28 * size.width,
                  delayMs: 600,
                ),
                _PulseDot(
                  bottom: 0.42 * size.height,
                  right: 0.24 * size.width,
                  delayMs: 1800,
                ),
                _PulseDot(
                  top: 0.40 * size.height,
                  left: 0.08 * size.width,
                  delayMs: 3000,
                ),
              ],
              // Scan lines
              if (_showDecor) ...[
                const _ScanLine(delayMs: 0),
                const _ScanLine(delayMs: 4500),
              ],
              // Corners
              if (_showDecor) ...[
                _CornerMark(top: 36, left: 36, isTL: true),
                _CornerMark(top: 36, right: 36, isTR: true),
                _CornerMark(bottom: 36, left: 36, isBL: true),
                _CornerMark(bottom: 36, right: 36, isBR: true),
              ],
              // Content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _HLine(expanded: _lineTopExpanded, isBottom: false),
                    const SizedBox(height: 52),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        ..._text
                            .split('')
                            .asMap()
                            .entries
                            .map(
                              (e) => _AnimatedLetter(
                                letter: e.value,
                                visible: _letterVisible[e.key],
                              ),
                            ),
                        _AnimatedDash(visible: _showDash),
                        _AnimatedAI(visible: _showAI),
                      ],
                    ),
                    _Subtitle(visible: _showSubtitle),
                    const SizedBox(height: 52),
                    _HLine(expanded: _lineBottomExpanded, isBottom: true),
                  ],
                ),
              ),
              // Version + line
              if (_showVersion) ...[
                const _VersionLine(visible: true),
                const _VersionLabel(visible: true),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
