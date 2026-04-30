import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const SportsSenseApp());
}

class SportsSenseApp extends StatelessWidget {
  const SportsSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPORTSENSE-AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF000000),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF000000),
          selectedItemColor: Color(0xFFFFFFFF),
          unselectedItemColor: Color(0xFF3A3A3A),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

// --- ДАННЫЕ ---
final predData = {
  'league': 'Ла Лига',
  'team1': 'Реал Мадрид',
  'team2': 'Барселона',
  'p1': 45,
  'draw': 25,
  'p2': 30,
  'tip': 'П1',
  'conf': 78,
  'date': '26 янв, 22:00',
  'form1': [3, 3, 1, 3, 0],
  'form2': [3, 1, 3, 0, 3],
};

final matchData = {
  'league': 'Ла Лига',
  'team1': 'Атлетико',
  'team2': 'Севилья',
  's1': 2,
  's2': 1,
  'minute': "67'",
  'viewers': '842K',
};

final teamAnalytics = {
  'name': 'Реал Мадрид',
  'form': [3, 3, 1, 3, 0, 3, 1, 3, 3, 1],
  'xg': [2.1, 1.8, 0.9, 2.4, 0.3, 1.7, 1.1, 2.0, 2.8, 0.7],
  'goals': [3, 2, 1, 2, 0, 1, 1, 2, 3, 1],
  'labels': [
    'Вал',
    'Бар',
    'Атл',
    'Сев',
    'Бет',
    'Хир',
    'Вал',
    'Осас',
    'Хет',
    'Май',
  ],
  'wins': 7,
  'draws': 2,
  'losses': 1,
  'cs': 5,
  'xgAvg': '1.58',
  'goalsAvg': '1.6',
};

// --- ГЛАВНЫЙ ЭКРАН ---
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _pages = [
    const HomePage(),
    const PredictionsPage(),
    const AnalyticsPage(),
    const MatchesPage(),
    const ChatPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF1C1C1C), width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined, size: 22),
              activeIcon: Icon(Icons.home, size: 22),
              label: 'ГЛАВНАЯ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.psychology_outlined, size: 22),
              activeIcon: Icon(Icons.psychology, size: 22),
              label: 'ПРОГНОЗЫ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.show_chart_outlined, size: 22),
              activeIcon: Icon(Icons.show_chart, size: 22),
              label: 'АНАЛИТИКА',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.live_tv_outlined, size: 22),
              activeIcon: Icon(Icons.live_tv, size: 22),
              label: 'МАТЧИ',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.smart_toy_outlined, size: 22),
              activeIcon: Icon(Icons.smart_toy, size: 22),
              label: 'ИИ ЧАТ',
            ),
          ],
        ),
      ),
    );
  }
}

// --- 1. ГЛАВНАЯ ---
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xFF060606), Color(0xFF000000)],
                radius: 0.8,
              ),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: GridPainter(_controller.value),
                child: const SizedBox.expand(),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Text(
                    'POWERED BY ARTIFICIAL INTELLIGENCE',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 4,
                      color: Color(0xFF777777),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SPORTSENSE',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 40,
                      letterSpacing: 8,
                      color: Color(0xFFFFFFFF),
                      height: 0.9,
                    ),
                  ),
                  Text(
                    '-AI',
                    style: GoogleFonts.bebasNeue(
                      fontSize: 24,
                      letterSpacing: 12,
                      color: Color(0xFF00E676),
                    ),
                  ),
                  Container(
                    width: 32,
                    height: 1,
                    color: const Color(0xFF3A3A3A),
                    margin: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  const Text(
                    'Интеллектуальный анализ футбола',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF777777),
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStat('1,247', 'МАТЧЕЙ'),
                      const SizedBox(width: 20),
                      _buildStat('87.3%', 'ТОЧНОСТЬ'),
                      const SizedBox(width: 20),
                      _buildStat('24', 'ЛИГИ'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    onPressed: () {
                      final state = context
                          .findAncestorStateOfType<_MainScreenState>();
                      state?.setState(() => state._currentIndex = 1);
                    },
                    child: const Text('НАЧАТЬ АНАЛИЗ'),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.bebasNeue(
            fontSize: 28,
            letterSpacing: 1,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10,
            fontWeight: FontWeight.w500,
            letterSpacing: 2,
            color: Color(0xFF3A3A3A),
          ),
        ),
      ],
    );
  }
}

class GridPainter extends CustomPainter {
  final double time;
  GridPainter(this.time);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x0AFFFFFF)
      ..strokeWidth = 0.5;
    final dotPaint = Paint();
    const sp = 50.0;

    for (double x = sp; x < size.width; x += sp) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = sp; y < size.height; y += sp) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }

    for (double x = sp; x < size.width; x += sp) {
      for (double y = sp; y < size.height; y += sp) {
        final v =
            (math.sin(time * 2 * math.pi * 0.001 + x * 0.015 + y * 0.012) *
                0.5 +
            0.5);
        if (v > 0.7) {
          final alpha = (v - 0.7) * 1.5;
          dotPaint.color = Color.fromRGBO(255, 255, 255, alpha.clamp(0.0, 1.0));
          canvas.drawCircle(Offset(x, y), 1.2 * v, dotPaint);
        }
      }
    }

    // Лучи
    final beamPaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              Colors.transparent,
              const Color(0x08FFFFFF),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCenter(
              center: Offset(
                size.width *
                    (math.sin(time * 2 * math.pi * 0.0002) * 0.5 + 0.5),
                size.height / 2,
              ),
              width: 160,
              height: size.height,
            ),
          );
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(
          size.width * (math.sin(time * 2 * math.pi * 0.0002) * 0.5 + 0.5),
          size.height / 2,
        ),
        width: 160,
        height: size.height,
      ),
      beamPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- 2. ПРОГНОЗЫ ---
class PredictionsPage extends StatelessWidget {
  const PredictionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Прогнозы',
              style: TextStyle(
                fontFamily: 'Bebas Neue',
                fontSize: 26,
                letterSpacing: 2,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'AI-анализ на основе 147 параметров',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF777777),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              border: Border.all(color: const Color(0xFF1C1C1C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  predData['league'] as String,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    color: Color(0xFF3A3A3A),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: (predData['form1'] as List)
                                .map(
                                  (e) => Container(
                                    width: 4,
                                    height:
                                        (e == 3
                                                ? 20
                                                : e == 1
                                                ? 8
                                                : 4)
                                            .toDouble(),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    color: e == 3
                                        ? Colors.white
                                        : e == 1
                                        ? const Color(0xFF444444)
                                        : const Color(0xFF222222),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            predData['team1'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'VS',
                        style: TextStyle(
                          fontFamily: 'Bebas Neue',
                          fontSize: 16,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: (predData['form2'] as List)
                                .map(
                                  (e) => Container(
                                    width: 4,
                                    height:
                                        (e == 3
                                                ? 20
                                                : e == 1
                                                ? 8
                                                : 4)
                                            .toDouble(),
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1,
                                    ),
                                    color: e == 3
                                        ? Colors.white
                                        : e == 1
                                        ? const Color(0xFF444444)
                                        : const Color(0xFF222222),
                                  ),
                                )
                                .toList(),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            predData['team2'] as String,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: SizedBox(
                    height: 6,
                    child: Row(
                      children: [
                        Expanded(
                          flex: predData['p1'] as int,
                          child: Container(color: const Color(0xCCFFFFFF)),
                        ),
                        Expanded(
                          flex: predData['draw'] as int,
                          child: Container(color: const Color(0x40FFFFFF)),
                        ),
                        Expanded(
                          flex: predData['p2'] as int,
                          child: Container(color: const Color(0xCCFFFFFF)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${predData['p1']}% П1',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                    ),
                    Text(
                      '${predData['draw']}% Х',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                    ),
                    Text(
                      '${predData['p2']}% П2',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: Color(0xFF777777),
                      ),
                    ),
                  ],
                ),
                Container(
                  margin: const EdgeInsets.only(top: 16, bottom: 12),
                  height: 1,
                  color: const Color(0xFF1C1C1C),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      color: const Color(0x1400E676),
                      child: Text(
                        predData['tip'] as String,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF00E676),
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Точность: ${predData['conf']}%',
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            color: Color(0xFF777777),
                          ),
                        ),
                        Text(
                          predData['date'] as String,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            color: Color(0xFF3A3A3A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 3. АНАЛИТИКА ---
class AnalyticsPage extends StatelessWidget {
  const AnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final d = teamAnalytics;
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Аналитика',
              style: TextStyle(
                fontFamily: 'Bebas Neue',
                fontSize: 26,
                letterSpacing: 2,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Глубокая статистика: ${d['name']}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF777777),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              border: Border.all(color: const Color(0xFF1C1C1C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Форма — последние 10 матчей (очки)',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: Color(0xFF777777),
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: FormChartPainter(
                      d['form'] as List<int>,
                      d['labels'] as List<String>,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              border: Border.all(color: const Color(0xFF1C1C1C)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'xG — ожидаемые голы vs фактически',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                      color: Color(0xFF777777),
                    ),
                  ),
                ),
                SizedBox(
                  height: 200,
                  child: CustomPaint(
                    painter: XgChartPainter(
                      d['xg'] as List<double>,
                      d['goals'] as List<int>,
                      d['labels'] as List<String>,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: [
              _statCard(d['wins'].toString(), 'ПОБЕДЫ', Colors.white),
              _statCard(d['draws'].toString(), 'НИЧЬИ', Colors.white),
              _statCard(
                d['losses'].toString(),
                'ПОРАЖЕНИЯ',
                const Color(0xFFFF5252),
              ),
              _statCard(d['cs'].toString(), 'СУХИЕ МАТЧИ', Colors.white),
              _statCard(d['xgAvg'].toString(), 'xG СРЕДН.', Colors.white),
              _statCard(d['goalsAvg'].toString(), 'ГОЛЫ СРЕДН.', Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String val, String label, Color valColor) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        border: Border.all(color: const Color(0xFF1C1C1C)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            val,
            style: TextStyle(
              fontFamily: 'Bebas Neue',
              fontSize: 32,
              color: valColor,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.5,
              color: Color(0xFF3A3A3A),
            ),
          ),
        ],
      ),
    );
  }
}

class FormChartPainter extends CustomPainter {
  final List<int> form;
  final List<String> labels;
  FormChartPainter(this.form, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 3; i++) {
      final y = 20.0 + (160.0 / 3) * i;
      canvas.drawLine(
        const Offset(32, 0) + Offset(0, y),
        Offset(size.width - 16, 0) + Offset(0, y),
        p,
      );
    }

    final path = Path();
    for (int i = 0; i < form.length; i++) {
      final x = 32.0 + ((size.width - 48) / (form.length - 1)) * i;
      final y = 20.0 + 160.0 - (form[i] / 3.0) * 160.0;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );

    for (int i = 0; i < form.length; i++) {
      final x = 32.0 + ((size.width - 48) / (form.length - 1)) * i;
      final y = 20.0 + 160.0 - (form[i] / 3.0) * 160.0;
      canvas.drawCircle(
        Offset(x, y),
        4,
        Paint()
          ..color = form[i] == 3
              ? const Color(0xFF00E676)
              : form[i] == 1
              ? const Color(0xFF888888)
              : const Color(0xFFFF5252),
      );
      canvas.drawCircle(
        Offset(x, y),
        1.5,
        Paint()..color = const Color(0xFF0E0E0E),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class XgChartPainter extends CustomPainter {
  final List<double> xg;
  final List<int> goals;
  final List<String> labels;
  XgChartPainter(this.xg, this.goals, this.labels);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = const Color(0x0FFFFFFF)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= 4; i++) {
      final y = 20.0 + (160.0 / 4) * i;
      canvas.drawLine(
        const Offset(32, 0) + Offset(0, y),
        Offset(size.width - 16, 0) + Offset(0, y),
        p,
      );
    }

    final maxV =
        (xg + goals.map((e) => e.toDouble()).toList())
            .reduce((a, b) => a > b ? a : b)
            .ceilToDouble() +
        0.5;

    final xgPath = Path();
    for (int i = 0; i < xg.length; i++) {
      final x = 32.0 + ((size.width - 48) / (xg.length - 1)) * i;
      final y = 20.0 + 160.0 - (xg[i] / maxV) * 160.0;
      i == 0 ? xgPath.moveTo(x, y) : xgPath.lineTo(x, y);
    }
    canvas.drawPath(
      xgPath,
      Paint()
        ..color = const Color(0x80FFFFFF)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    final gPath = Path();
    for (int i = 0; i < goals.length; i++) {
      final x = 32.0 + ((size.width - 48) / (goals.length - 1)) * i;
      final y = 20.0 + 160.0 - (goals[i] / maxV) * 160.0;
      i == 0 ? gPath.moveTo(x, y) : gPath.lineTo(x, y);
      canvas.drawCircle(
        Offset(x, y),
        3,
        Paint()..color = const Color(0xFF00E676),
      );
    }
    canvas.drawPath(
      gPath,
      Paint()
        ..color = const Color(0xFF00E676)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// --- 4. МАТЧИ ---
class MatchesPage extends StatelessWidget {
  const MatchesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
            child: Text(
              'Матчи',
              style: TextStyle(
                fontFamily: 'Bebas Neue',
                fontSize: 26,
                letterSpacing: 2,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Text(
              'Смотрите матчи в прямом эфире',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF777777),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0E0E0E),
              border: Border.all(color: const Color(0xFF1C1C1C)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: const BoxDecoration(color: Color(0x14FF5252)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFFF5252),
                            ),
                          ),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              color: Color(0xFFFF5252),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        matchData['league'] as String,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          matchData['team1'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        '${matchData['s1']} : ${matchData['s2']}',
                        style: const TextStyle(
                          fontFamily: 'Bebas Neue',
                          fontSize: 28,
                          letterSpacing: 1,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          matchData['team2'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF1C1C1C))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.remove_red_eye_outlined,
                            size: 14,
                            color: Color(0xFF3A3A3A),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            matchData['viewers'] as String,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF3A3A3A),
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => _showVideoModal(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          color: const Color(0xFFFF5252),
                          child: const Text(
                            'СМОТРЕТЬ',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showVideoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
      ),
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          children: [
            Container(height: 1, color: const Color(0xFF1C1C1C)),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Атлетико vs Севилья',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: const Color(0xFF0E0E0E),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.play_circle_outline,
                  size: 60,
                  color: Color(0x20FFFFFF),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    height: 3,
                    color: const Color(0xFF1C1C1C),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.35,
                      child: Container(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '32:15 / 90:00',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                      Icon(
                        Icons.fullscreen,
                        size: 18,
                        color: Color(0xFF777777),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 5. ИИ ЧАТ ---
class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<Map<String, String>> _messages = [
    {
      'role': 'bot',
      'text':
          'Привет! Я ваш ИИ-помощник по футболу. Спросите меня о прогнозах или статистике.',
    },
  ];
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _isTyping = false;

  void _sendMessage() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _messages.add({'role': 'user', 'text': _controller.text.trim()});
      _isTyping = true;
    });
    _controller.clear();
    _scrollToBottom();

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _isTyping = false;
        _messages.add({
          'role': 'bot',
          'text':
              'На основе анализа xG и текущей формы, рекомендую обратить внимание на тотал больше. Модель показывает точность 87.3%.',
        });
      });
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFF1C1C1C))),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1C1C1C)),
                  color: const Color(0xFF141414),
                ),
                child: const Icon(
                  Icons.smart_toy,
                  size: 16,
                  color: Color(0xFF00E676),
                ),
              ),
              const SizedBox(width: 10),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SPORTSENSE AI',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Онлайн',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: Color(0xFF00E676),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, i) {
              if (i == _messages.length) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E0E),
                      border: Border.all(color: const Color(0xFF1C1C1C)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 5,
                          height: 5,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3A3A3A),
                          ),
                        ),
                        SizedBox(width: 5),
                        SizedBox(
                          width: 5,
                          height: 5,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3A3A3A),
                          ),
                        ),
                        SizedBox(width: 5),
                        SizedBox(
                          width: 5,
                          height: 5,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF3A3A3A),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final msg = _messages[i];
              final isUser = msg['role'] == 'user';
              return Align(
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isUser ? Colors.white : const Color(0xFF0E0E0E),
                    border: isUser
                        ? null
                        : Border.all(color: const Color(0xFF1C1C1C)),
                  ),
                  child: Text(
                    msg['text']!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: isUser ? Colors.black : Colors.white,
                      height: 1.4,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 10,
          ).copyWith(bottom: 10 + MediaQuery.of(context).padding.bottom),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0xFF1C1C1C))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: Colors.white,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Задайте вопрос...',
                    hintStyle: const TextStyle(
                      color: Color(0xFF3A3A3A),
                      fontFamily: 'Inter',
                    ),
                    filled: true,
                    fillColor: const Color(0xFF0E0E0E),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(0),
                      borderSide: const BorderSide(color: Color(0xFF1C1C1C)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.zero,
                child: InkWell(
                  onTap: _sendMessage,
                  child: Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.arrow_upward,
                      color: Colors.black,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
