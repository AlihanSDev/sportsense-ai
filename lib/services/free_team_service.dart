import 'dart:convert';

import 'package:http/http.dart' as http;

class TeamSummary {
  final String name;
  final String? country;
  final String? logoUrl;

  const TeamSummary({required this.name, this.country, this.logoUrl});
}

class FreeTeamService {
  final http.Client _client;

  FreeTeamService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<TeamSummary>> getPremierLeagueTeams() async {
    return _fetchTeams('English Premier League');
  }

  Future<List<TeamSummary>> _fetchTeams(String league) async {
    final uri = Uri.https(
      'www.thesportsdb.com',
      '/api/v1/json/1/search_all_teams.php',
      {'l': league},
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception(
        'Не удалось загрузить команды: HTTP ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final rawTeams = (decoded['teams'] as List?) ?? const [];

    return rawTeams
        .whereType<Map<String, dynamic>>()
        .map((team) {
          final name = (team['strTeam'] as String?)?.trim() ?? '';
          return TeamSummary(
            name: name,
            country: (team['strCountry'] as String?)?.trim(),
            logoUrl: (team['strTeamBadge'] as String?)?.trim(),
          );
        })
        .where((team) => team.name.isNotEmpty)
        .toList();
  }
}
