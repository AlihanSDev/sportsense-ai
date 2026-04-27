export 'api_football_service.dart';

import 'api_football_service.dart';

class LeagueOption {
  final String id;
  final String name;

  const LeagueOption({required this.id, required this.name});
}

class MatchFeed {
  final List<FootballMatch> matches;
  final List<LeagueOption> leagues;

  const MatchFeed({required this.matches, required this.leagues});
}

class MatchesService {
  final ApiFootballService _apiFootballService;

  MatchesService({ApiFootballService? apiFootballService})
    : _apiFootballService = apiFootballService ?? ApiFootballService();

  Future<List<FootballMatch>> getLiveMatches() {
    return _apiFootballService.getLiveMatches();
  }

  Future<List<FootballMatch>> getTodayMatches() {
    return _apiFootballService.getTodayMatches();
  }

  Future<List<FootballMatch>> getMatchesByLeague({
    required int leagueId,
    required int season,
  }) {
    return _apiFootballService.getMatchesByLeague(
      leagueId: leagueId,
      season: season,
    );
  }

  Future<MatchFeed> fetchMatchFeed({required bool liveOnly}) async {
    final matches = liveOnly ? await getLiveMatches() : await getTodayMatches();
    final sorted = List<FootballMatch>.from(matches)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    final leaguesMap = <String, LeagueOption>{};
    for (final match in sorted) {
      leaguesMap['${match.leagueId}'] = LeagueOption(
        id: '${match.leagueId}',
        name: match.leagueName,
      );
    }

    final leagues = leaguesMap.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    return MatchFeed(matches: sorted, leagues: leagues);
  }
}
