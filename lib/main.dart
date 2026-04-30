import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/api_football_service.dart';
import 'services/free_team_service.dart';
import 'services/matches_service.dart';
import 'services/qwen_api_service.dart';
import 'services/uefa_parser.dart';

bool isSupabaseConfigured = false;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();

  final supabaseUrl = dotenv.env['SUPABASE_URL']?.trim();
  final supabaseKey = dotenv.env['SUPABASE_ANON_KEY']?.trim();

  if (supabaseUrl?.isNotEmpty == true && supabaseKey?.isNotEmpty == true) {
    await Supabase.initialize(url: supabaseUrl!, anonKey: supabaseKey!);
    isSupabaseConfigured = true;
  }

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

final apiFootballService = ApiFootballService();
final freeTeamService = FreeTeamService();
final qwenApiService = QwenApiService();
final uefaParser = UefaParser();

final newsItems = const [
  _NewsItem(
    title: 'Фавориты удерживают темп в верхней части таблицы.',
    time: '15 мар',
    imageUrl:
        'https://images.unsplash.com/photo-1574629810360-7efbbe195018?auto=format&fit=crop&w=900&q=80',
  ),
  _NewsItem(
    title: 'Ключевой матч следующего тура может изменить расстановку лидеров.',
    time: '42 мин',
    imageUrl:
        'https://images.unsplash.com/photo-1518091043644-c1d4457512c6?auto=format&fit=crop&w=900&q=80',
  ),
  _NewsItem(
    title: 'Молодые игроки становятся заметным фактором в текущем розыгрыше.',
    time: '1 ч',
    imageUrl:
        'https://images.unsplash.com/photo-1547347298-4074fc3086f0?auto=format&fit=crop&w=900&q=80',
  ),
];

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
    const NewsPage(),
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
              icon: Icon(Icons.article_outlined, size: 22),
              activeIcon: Icon(Icons.article, size: 22),
              label: 'НОВОСТИ',
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
class PredictionsPage extends StatefulWidget {
  const PredictionsPage({super.key});

  @override
  State<PredictionsPage> createState() => _PredictionsPageState();
}

class _PredictionsPageState extends State<PredictionsPage> {
  late final Future<List<TeamSummary>> _teamsFuture;

  @override
  void initState() {
    super.initState();
    _teamsFuture = freeTeamService.getPremierLeagueTeams();
  }

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Клубы для прогноза',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: Color(0xFF777777),
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 128,
                  child: FutureBuilder<List<TeamSummary>>(
                    future: _teamsFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: 3,
                          separatorBuilder: (context, _) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) => Container(
                            width: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF111111),
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        );
                      }

                      final teams = snapshot.data;
                      if (teams == null || teams.isEmpty) {
                        return Center(
                          child: Text(
                            snapshot.hasError
                                ? 'Не удалось загрузить клубы'
                                : 'Клубы не найдены',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              color: Color(0xFF777777),
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: teams.length,
                        separatorBuilder: (context, _) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final team = teams[index];
                          return _ClubCard(team: team);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
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

class _ClubCard extends StatelessWidget {
  final TeamSummary team;

  const _ClubCard({required this.team});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C1C1C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 74,
            width: double.infinity,
            child: team.logoUrl != null
                ? Image.network(
                    team.logoUrl!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.shield_outlined,
                        color: Colors.white30,
                        size: 32,
                      ),
                    ),
                  )
                : const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Colors.white30,
                      size: 32,
                    ),
                  ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  team.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  team.country ?? 'Международный',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    color: Color(0xFF777777),
                  ),
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
class NewsPage extends StatelessWidget {
  const NewsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      itemCount: newsItems.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Новости',
                style: TextStyle(
                  fontFamily: 'Bebas Neue',
                  fontSize: 26,
                  letterSpacing: 2,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Свежие футбольные новости и аналитические заметки для быстрого просмотра.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF777777),
                ),
              ),
              SizedBox(height: 20),
            ],
          );
        }

        final item = newsItems[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _NewsCard(item: item),
        );
      },
    );
  }
}

class _NewsItem {
  final String title;
  final String time;
  final String imageUrl;

  const _NewsItem({
    required this.title,
    required this.time,
    required this.imageUrl,
  });
}

class _NewsCard extends StatelessWidget {
  final _NewsItem item;

  const _NewsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1C1C1C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Image.network(
              item.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF151515),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.image_not_supported_rounded,
                    color: Colors.white54,
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    item.time,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Color(0xFF8A8A8A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Читать дальше',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: Colors.greenAccent.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
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
class MatchesPage extends StatefulWidget {
  const MatchesPage({super.key});

  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  bool _isLoading = true;
  String? _error;
  List<FootballMatch> _matches = [];
  List<String> _uefaMatches = [];
  List<MatchItem> _newMatches = [];

  @override
  void initState() {
    super.initState();
    _loadMatches();
  }

  Future<void> _loadMatches() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _matches = [];
      _uefaMatches = [];
      _newMatches = [];
    });

    try {
      final liveMatches = await apiFootballService.getLiveMatches();
      if (liveMatches.isNotEmpty) {
        _matches = liveMatches;
      } else {
        _matches = await apiFootballService.getTodayMatches();
      }
    } catch (e) {
      _error = 'API Football: ${e.toString()}';
      _matches = [];
    }

    try {
      _uefaMatches = await uefaParser.fetchRecentMatches();
    } catch (e) {
      final message = 'UEFA source: ${e.toString()}';
      _error = _error == null ? message : '$_error\n$message';
      _uefaMatches = [];
    }

    try {
      _newMatches = await MatchesService().fetchMatches();
    } catch (e) {
      final message = 'SportsDB: ${e.toString()}';
      _error = _error == null ? message : '$_error\n$message';
      _newMatches = [];
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadMatches,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        physics: const AlwaysScrollableScrollPhysics(),
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
              'Смотрите матчи в прямом эфире и дополнительные сведения из UEFA.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Color(0xFF777777),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E0E),
                border: Border.all(color: const Color(0xFF1C1C1C)),
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          if (_error != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E0E),
                border: Border.all(color: const Color(0xFF1C1C1C)),
              ),
              child: Text(
                _error!,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFFFF5252),
                ),
              ),
            ),
          if (!_isLoading &&
              _matches.isEmpty &&
              _uefaMatches.isEmpty &&
              _newMatches.isEmpty &&
              _error == null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0E0E0E),
                border: Border.all(color: const Color(0xFF1C1C1C)),
              ),
              child: const Text(
                'Матчи не найдены. Потяните вниз, чтобы обновить.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: Color(0xFF777777),
                ),
              ),
            ),
          if (_matches.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'API Football',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final match in _matches)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
                  border: Border.all(color: const Color(0xFF1C1C1C)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(color: Color(0x1400E676)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            match.leagueName,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2,
                              color: Color(0xFF00E676),
                            ),
                          ),
                          Text(
                            match.country,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: Color(0xFF777777),
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
                              match.homeTeam,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${match.homeScore ?? '-'} : ${match.awayScore ?? '-'}',
                            style: const TextStyle(
                              fontFamily: 'Bebas Neue',
                              fontSize: 28,
                              letterSpacing: 1,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              match.awayTeam,
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
                        border: Border(
                          top: BorderSide(color: Color(0xFF1C1C1C)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            match.statusLong.isNotEmpty
                                ? '${match.statusLong}${match.elapsed != null ? ' · ${match.elapsed}\'' : ''}'
                                : 'Статус неизвестен',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF777777),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _showVideoModal(context, match),
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
          if (_uefaMatches.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'UEFA: дополнительные матчи',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final summary in _uefaMatches)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF1C1C1C)),
                ),
                child: Text(
                  summary,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
          if (_newMatches.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'TheSportsDB: актуальные матчи',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final match in _newMatches)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E0E0E),
                  border: Border.all(color: const Color(0xFF1C1C1C)),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: const BoxDecoration(color: Color(0x142196F3)),
                      child: Text(
                        match.competition,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 2,
                          color: Color(0xFF2196F3),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              match.homeTeam,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Text(
                            '${match.homeScore ?? '-'} : ${match.awayScore ?? '-'}',
                            style: const TextStyle(
                              fontFamily: 'Bebas Neue',
                              fontSize: 28,
                              letterSpacing: 1,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              match.awayTeam,
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
                        border: Border(
                          top: BorderSide(color: Color(0xFF1C1C1C)),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatKickoff(match.kickoff),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11,
                              color: Color(0xFF777777),
                            ),
                          ),
                          if (match.status != null)
                            Text(
                              match.status!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: Color(0xFF777777),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  String _formatKickoff(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$day.$month  $hour:$minute';
  }

  void _showVideoModal(BuildContext context, FootballMatch match) {
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
                  Expanded(
                    child: Text(
                      '${match.homeTeam} vs ${match.awayTeam}',
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        match.statusLong.isNotEmpty
                            ? '${match.statusLong}${match.elapsed != null ? ' · ${match.elapsed}\'' : ''}'
                            : 'Статус неизвестен',
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: Color(0xFF3A3A3A),
                        ),
                      ),
                      const Icon(
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
