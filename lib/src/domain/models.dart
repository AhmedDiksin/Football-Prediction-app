enum MatchStatus { scheduled, live, finished, postponed }

enum MatchOutcome { home, away, draw, unknown }

class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarColor = 0xff5af28a,
  });

  final String id;
  final String email;
  final String? displayName;
  final int avatarColor;

  bool get hasProfile => displayName != null && displayName!.trim().isNotEmpty;

  AppUser copyWith({String? displayName, int? avatarColor}) {
    return AppUser(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarColor: avatarColor ?? this.avatarColor,
    );
  }
}

class Team {
  const Team({
    required this.id,
    required this.name,
    required this.shortName,
    required this.countryCode,
    this.badgeUrl,
  });

  final String id;
  final String name;
  final String shortName;
  final String countryCode;
  final String? badgeUrl;
}

class FixtureMatch {
  const FixtureMatch({
    required this.id,
    required this.homeTeam,
    required this.awayTeam,
    required this.kickoffAt,
    required this.status,
    this.homeScore,
    this.awayScore,
    this.stage = 'Group stage',
    this.venue,
  });

  final String id;
  final Team homeTeam;
  final Team awayTeam;
  final DateTime kickoffAt;
  final MatchStatus status;
  final int? homeScore;
  final int? awayScore;
  final String stage;
  final String? venue;

  bool get isLocked => DateTime.now().toUtc().isAfter(kickoffAt.toUtc());
  bool get hasFinalScore =>
      status == MatchStatus.finished && homeScore != null && awayScore != null;

  FixtureMatch copyWith({MatchStatus? status, int? homeScore, int? awayScore}) {
    return FixtureMatch(
      id: id,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      kickoffAt: kickoffAt,
      status: status ?? this.status,
      homeScore: homeScore ?? this.homeScore,
      awayScore: awayScore ?? this.awayScore,
      stage: stage,
      venue: venue,
    );
  }
}

class Prediction {
  const Prediction({
    required this.matchId,
    required this.userId,
    required this.homeScore,
    required this.awayScore,
    this.points,
    this.exact = false,
  });

  final String matchId;
  final String userId;
  final int homeScore;
  final int awayScore;
  final int? points;
  final bool exact;
}

class MatchWithPrediction {
  const MatchWithPrediction({
    required this.match,
    this.prediction,
    this.homePickPercent = 0,
    this.awayPickPercent = 0,
    this.drawPickPercent = 0,
  });

  final FixtureMatch match;
  final Prediction? prediction;
  final int homePickPercent;
  final int awayPickPercent;
  final int drawPickPercent;
}

class LeagueSummary {
  const LeagueSummary({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.rank,
    required this.totalPlayers,
    required this.points,
    required this.isGlobal,
    this.inviteCode,
  });

  final String id;
  final String name;
  final int memberCount;
  final int rank;
  final int totalPlayers;
  final int points;
  final bool isGlobal;
  final String? inviteCode;
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.userId,
    required this.displayName,
    required this.rank,
    required this.points,
    required this.exactScores,
    this.isCurrentUser = false,
  });

  final String userId;
  final String displayName;
  final int rank;
  final int points;
  final int exactScores;
  final bool isCurrentUser;
}
