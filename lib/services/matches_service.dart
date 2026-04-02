import 'dart:convert';

import 'package:http/http.dart' as http;

class MatchItem {
  final String id;
  final String leagueId;
  final String competition;
  final String homeTeam;
  final String awayTeam;
  final DateTime kickoff;
  final String? venue;
  final String? homeBadge;
  final String? awayBadge;
  final String? status;
  final String? homeScore;
  final String? awayScore;

  const MatchItem({
    required this.id,
    required this.leagueId,
    required this.competition,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoff,
    this.venue,
    this.homeBadge,
    this.awayBadge,
    this.status,
    this.homeScore,
    this.awayScore,
  });

  factory MatchItem.fromJson(Map<String, dynamic> json) {
    final date = json['dateEvent'] as String?;
    final time = (json['strTime'] as String?) ?? '00:00:00';
    final kickoff = _parseKickoff(date, time);

    return MatchItem(
      id: (json['idEvent'] as String?) ?? '${json['strHomeTeam']}_${json['strAwayTeam']}_$date',
      leagueId: (json['idLeague'] as String?) ?? 'unknown',
      competition: (json['strLeague'] as String?) ?? 'Football',
      homeTeam: (json['strHomeTeam'] as String?) ?? 'TBD',
      awayTeam: (json['strAwayTeam'] as String?) ?? 'TBD',
      kickoff: kickoff,
      venue: json['strVenue'] as String?,
      homeBadge: json['strHomeTeamBadge'] as String?,
      awayBadge: json['strAwayTeamBadge'] as String?,
      status: json['strStatus'] as String?,
      homeScore: json['intHomeScore']?.toString(),
      awayScore: json['intAwayScore']?.toString(),
    );
  }

  static DateTime _parseKickoff(String? date, String time) {
    if (date == null || date.isEmpty) {
      return DateTime.now().toUtc();
    }

    final normalizedTime = time.length == 5 ? '$time:00' : time;
    return DateTime.tryParse('${date}T${normalizedTime}Z') ??
        DateTime.now().toUtc();
  }
}

class LeagueOption {
  final String id;
  final String name;

  const LeagueOption({
    required this.id,
    required this.name,
  });
}

class MatchFeed {
  final List<MatchItem> matches;
  final List<LeagueOption> leagues;

  const MatchFeed({
    required this.matches,
    required this.leagues,
  });
}

class MatchesService {
  static const _baseUrl = 'https://www.thesportsdb.com/api/v1/json/123';
  static const priorityLeagueIds = {'4480', '4481', '4328', '4335', '4332'};

  final http.Client _client;

  MatchesService({http.Client? client}) : _client = client ?? http.Client();

  Future<MatchFeed> fetchMatchFeed() async {
    final now = DateTime.now();
    final dates = [now, now.add(const Duration(days: 1))];
    final events = <MatchItem>[];

    for (final date in dates) {
      final items = await _fetchMatchesForDate(date);
      events.addAll(items);
    }

    final unique = <String, MatchItem>{};
    for (final item in events) {
      unique[item.id] = item;
    }

    final sorted = unique.values.toList()
      ..sort((a, b) => a.kickoff.compareTo(b.kickoff));

    final leaguesMap = <String, LeagueOption>{};
    for (final match in sorted) {
      leaguesMap[match.leagueId] = LeagueOption(
        id: match.leagueId,
        name: match.competition,
      );
    }

    final leagues = leaguesMap.values.toList()
      ..sort((a, b) {
        final aPriority = priorityLeagueIds.contains(a.id) ? 0 : 1;
        final bPriority = priorityLeagueIds.contains(b.id) ? 0 : 1;
        if (aPriority != bPriority) return aPriority.compareTo(bPriority);
        return a.name.compareTo(b.name);
      });

    return MatchFeed(
      matches: sorted,
      leagues: leagues,
    );
  }

  Future<List<MatchItem>> _fetchMatchesForDate(DateTime date) async {
    final formattedDate = _formatDate(date);
    final uri = Uri.parse(
      '$_baseUrl/eventsday.php?d=$formattedDate&s=Soccer',
    );
    final response = await _client.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load matches: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final events = (decoded['events'] as List?) ?? const [];

    return events
        .whereType<Map<String, dynamic>>()
        .map(MatchItem.fromJson)
        .toList();
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
