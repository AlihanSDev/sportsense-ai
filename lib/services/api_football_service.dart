import 'dart:convert';

import 'package:http/http.dart' as http;

const String _apiFootballKey = String.fromEnvironment('API_FOOTBALL_KEY');

class ApiFootballException implements Exception {
  final String message;

  const ApiFootballException(this.message);

  @override
  String toString() => message;
}

class FootballMatch {
  final String id;
  final int leagueId;
  final String leagueName;
  final String country;
  final String? leagueLogo;
  final String homeTeam;
  final String awayTeam;
  final String? homeLogo;
  final String? awayLogo;
  final int? homeScore;
  final int? awayScore;
  final DateTime startTime;
  final String statusShort;
  final String statusLong;
  final int? elapsed;

  const FootballMatch({
    required this.id,
    required this.leagueId,
    required this.leagueName,
    required this.country,
    required this.leagueLogo,
    required this.homeTeam,
    required this.awayTeam,
    required this.homeLogo,
    required this.awayLogo,
    required this.homeScore,
    required this.awayScore,
    required this.startTime,
    required this.statusShort,
    required this.statusLong,
    required this.elapsed,
  });

  bool get isLive =>
      elapsed != null || _liveStatuses.contains(statusShort.toUpperCase());

  factory FootballMatch.fromApiFootballJson(Map<String, dynamic> json) {
    final fixture =
        (json['fixture'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fixtureStatus =
        (fixture['status'] as Map?)?.cast<String, dynamic>() ?? const {};
    final league =
        (json['league'] as Map?)?.cast<String, dynamic>() ?? const {};
    final teams = (json['teams'] as Map?)?.cast<String, dynamic>() ?? const {};
    final home = (teams['home'] as Map?)?.cast<String, dynamic>() ?? const {};
    final away = (teams['away'] as Map?)?.cast<String, dynamic>() ?? const {};
    final goals = (json['goals'] as Map?)?.cast<String, dynamic>() ?? const {};

    return FootballMatch(
      id: '${fixture['id'] ?? ''}',
      leagueId: ApiFootballService._toInt(league['id']) ?? 0,
      leagueName: (league['name'] as String?)?.trim().isNotEmpty == true
          ? league['name'] as String
          : 'Football',
      country: (league['country'] as String?)?.trim().isNotEmpty == true
          ? league['country'] as String
          : 'Unknown',
      leagueLogo: league['logo'] as String?,
      homeTeam: (home['name'] as String?)?.trim().isNotEmpty == true
          ? home['name'] as String
          : 'TBD',
      awayTeam: (away['name'] as String?)?.trim().isNotEmpty == true
          ? away['name'] as String
          : 'TBD',
      homeLogo: home['logo'] as String?,
      awayLogo: away['logo'] as String?,
      homeScore: ApiFootballService._toInt(goals['home']),
      awayScore: ApiFootballService._toInt(goals['away']),
      startTime:
          DateTime.tryParse((fixture['date'] as String?) ?? '')?.toLocal() ??
          DateTime.now(),
      statusShort: (fixtureStatus['short'] as String?) ?? '',
      statusLong: (fixtureStatus['long'] as String?) ?? '',
      elapsed: ApiFootballService._toInt(fixtureStatus['elapsed']),
    );
  }
}

class ApiFootballService {
  static const String _baseUrl = 'https://v3.football.api-sports.io';

  final http.Client _client;

  ApiFootballService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<FootballMatch>> getLiveMatches() {
    return _fetchMatches(queryParameters: const {'live': 'all'});
  }

  Future<List<FootballMatch>> getTodayMatches() {
    final now = DateTime.now();
    final date = [
      now.year.toString().padLeft(4, '0'),
      now.month.toString().padLeft(2, '0'),
      now.day.toString().padLeft(2, '0'),
    ].join('-');

    return _fetchMatches(queryParameters: {'date': date});
  }

  Future<List<FootballMatch>> getMatchesByLeague({
    required int leagueId,
    required int season,
  }) {
    return _fetchMatches(
      queryParameters: {'league': '$leagueId', 'season': '$season'},
    );
  }

  Future<List<FootballMatch>> _fetchMatches({
    required Map<String, String> queryParameters,
  }) async {
    if (_apiFootballKey.trim().isEmpty) {
      throw const ApiFootballException(
        'API ключ не найден. Запустите приложение с --dart-define=API_FOOTBALL_KEY=...',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl/fixtures',
    ).replace(queryParameters: queryParameters);

    try {
      final response = await _client.get(
        uri,
        headers: {'x-apisports-key': _apiFootballKey},
      );

      final body = response.body;
      final decoded = body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(body) as Map<String, dynamic>;

      if (response.statusCode == 429 || _containsLimitError(decoded)) {
        throw const ApiFootballException('Лимит API запросов исчерпан');
      }

      if (response.statusCode != 200) {
        final apiError = _extractApiError(decoded);
        throw ApiFootballException(
          apiError ?? 'Ошибка API-FOOTBALL: HTTP ${response.statusCode}',
        );
      }

      final responseItems = (decoded['response'] as List?) ?? const [];

      return responseItems
          .whereType<Map>()
          .map(
            (item) =>
                FootballMatch.fromApiFootballJson(item.cast<String, dynamic>()),
          )
          .toList();
    } on ApiFootballException {
      rethrow;
    } catch (_) {
      throw const ApiFootballException(
        'Не удалось загрузить матчи. Проверьте соединение и повторите попытку.',
      );
    }
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String? _extractApiError(Map<String, dynamic> decoded) {
    final errors = decoded['errors'];
    if (errors is String && errors.trim().isNotEmpty) {
      return errors;
    }
    if (errors is List && errors.isNotEmpty) {
      return errors.first.toString();
    }
    if (errors is Map && errors.isNotEmpty) {
      return errors.values.first.toString();
    }
    final message = decoded['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    return null;
  }

  static bool _containsLimitError(Map<String, dynamic> decoded) {
    final errorText = [
      _extractApiError(decoded),
      decoded['message']?.toString(),
    ].whereType<String>().join(' ').toLowerCase();

    return errorText.contains('limit') ||
        errorText.contains('quota') ||
        errorText.contains('too many requests');
  }
}

const Set<String> _liveStatuses = {
  '1H',
  '2H',
  'HT',
  'ET',
  'BT',
  'P',
  'INT',
  'SUSP',
};
