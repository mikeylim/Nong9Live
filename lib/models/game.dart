import 'package:flutter/material.dart';

import 'game_event.dart';

enum ScoringMode {
  /// Regular basketball: FT 1, inside 2, outside 3.
  standard('2s & 3s', 'Regular scoring'),

  /// Pickup "1s and 2s": inside 1, outside 2.
  streetball('1s & 2s', 'Streetball scoring');

  const ScoringMode(this.short, this.label);
  final String short;
  final String label;

  int get insidePoints => this == standard ? 2 : 1;
  int get outsidePoints => this == standard ? 3 : 2;
  String get insideLabel => '${insidePoints}PT';
  String get outsideLabel => '${outsidePoints}PT';
}

class GameRules {
  GameRules({
    this.scoring = ScoringMode.standard,
    this.targetScore,
    this.winByTwo = false,
    this.minutes,
  });

  ScoringMode scoring;

  /// "First to N" (null = no target).
  int? targetScore;
  bool winByTwo;

  /// Optional running game clock length.
  int? minutes;

  String get summary {
    final parts = <String>[scoring.short];
    if (targetScore != null) parts.add('to $targetScore${winByTwo ? ' (win by 2)' : ''}');
    if (minutes != null) parts.add('$minutes min');
    return parts.join(' · ');
  }

  int pointsFor(EventType t) => switch (t) {
        EventType.ftMade => 1,
        EventType.insideMade => scoring.insidePoints,
        EventType.outsideMade => scoring.outsidePoints,
        _ => 0,
      };

  GameRules copy() => GameRules.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'scoring': scoring.name,
        'targetScore': targetScore,
        'winByTwo': winByTwo,
        'minutes': minutes,
      };

  factory GameRules.fromJson(Map<String, dynamic> j) => GameRules(
        scoring: ScoringMode.values.where((s) => s.name == j['scoring']).firstOrNull ??
            ScoringMode.standard,
        targetScore: (j['targetScore'] as num?)?.toInt(),
        winByTwo: j['winByTwo'] as bool? ?? false,
        minutes: (j['minutes'] as num?)?.toInt(),
      );
}

/// Pickup teams are usually just shirt colors.
const teamColorPresets = <(String, Color)>[
  ('White', Color(0xFFF1F1F1)),
  ('Black', Color(0xFF2B2B2B)),
  ('Red', Color(0xFFE53935)),
  ('Blue', Color(0xFF1E88E5)),
  ('Green', Color(0xFF43A047)),
  ('Yellow', Color(0xFFFDD835)),
  ('Orange', Color(0xFFFF6B1A)),
  ('Purple', Color(0xFF8E24AA)),
  ('Gray', Color(0xFF9E9E9E)),
  ('Navy', Color(0xFF283593)),
];

class TeamSide {
  TeamSide({required this.name, required this.colorValue, List<String>? playerIds})
      : playerIds = playerIds ?? <String>[];

  String name;
  int colorValue;
  List<String> playerIds;

  Color get color => Color(colorValue);

  /// Readable text color on top of the team color.
  Color get onColor =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : const Color(0xFF15171F);

  TeamSide copy() => TeamSide(name: name, colorValue: colorValue, playerIds: [...playerIds]);

  Map<String, dynamic> toJson() => {'name': name, 'colorValue': colorValue, 'playerIds': playerIds};

  factory TeamSide.fromJson(Map<String, dynamic> j) => TeamSide(
        name: j['name'] as String? ?? 'Team',
        colorValue: (j['colorValue'] as num?)?.toInt() ?? 0xFF9E9E9E,
        playerIds: ((j['playerIds'] as List?) ?? []).cast<String>(),
      );
}

enum GameStatus { live, finished }

class Game {
  Game({
    required this.id,
    required this.gameDayId,
    required this.number,
    required this.teams,
    required this.rules,
    this.status = GameStatus.live,
    DateTime? createdAt,
    this.startedAt,
    this.endedAt,
    this.clockRemainingMs,
    this.clockStartedAt,
    this.mvpOverrideId,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String gameDayId;
  int number;
  List<TeamSide> teams;
  GameRules rules;
  GameStatus status;
  final DateTime createdAt;
  DateTime? startedAt;
  DateTime? endedAt;

  /// Clock state. While running, [clockStartedAt] is when it was last
  /// resumed and [clockRemainingMs] is what was left at that moment.
  int? clockRemainingMs;
  DateTime? clockStartedAt;
  String? mvpOverrideId;

  bool get isLive => status == GameStatus.live;
  bool get isFinished => status == GameStatus.finished;
  bool get hasClock => rules.minutes != null;
  bool get clockRunning => clockStartedAt != null;

  int clockRemainingAt(DateTime now) {
    final base = clockRemainingMs ?? (rules.minutes ?? 0) * 60000;
    if (clockStartedAt == null) return base;
    return (base - now.difference(clockStartedAt!).inMilliseconds).clamp(0, base);
  }

  int? teamIndexOf(String playerId) {
    for (var i = 0; i < teams.length; i++) {
      if (teams[i].playerIds.contains(playerId)) return i;
    }
    return null;
  }

  Set<String> get allPlayerIds => {for (final t in teams) ...t.playerIds};

  String get title => 'Game $number';

  Duration? get duration =>
      startedAt == null ? null : (endedAt ?? DateTime.now()).difference(startedAt!);

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameDayId': gameDayId,
        'number': number,
        'teams': teams.map((t) => t.toJson()).toList(),
        'rules': rules.toJson(),
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'startedAt': startedAt?.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'clockRemainingMs': clockRemainingMs,
        'clockStartedAt': clockStartedAt?.toIso8601String(),
        'mvpOverrideId': mvpOverrideId,
      };

  factory Game.fromJson(Map<String, dynamic> j) => Game(
        id: j['id'] as String,
        gameDayId: j['gameDayId'] as String,
        number: (j['number'] as num?)?.toInt() ?? 1,
        teams: ((j['teams'] as List?) ?? [])
            .map((t) => TeamSide.fromJson((t as Map).cast<String, dynamic>()))
            .toList(),
        rules: GameRules.fromJson(((j['rules'] as Map?) ?? {}).cast<String, dynamic>()),
        status: GameStatus.values.where((s) => s.name == j['status']).firstOrNull ?? GameStatus.finished,
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        startedAt: DateTime.tryParse(j['startedAt'] as String? ?? ''),
        endedAt: DateTime.tryParse(j['endedAt'] as String? ?? ''),
        clockRemainingMs: (j['clockRemainingMs'] as num?)?.toInt(),
        clockStartedAt: DateTime.tryParse(j['clockStartedAt'] as String? ?? ''),
        mvpOverrideId: j['mvpOverrideId'] as String?,
      );
}
