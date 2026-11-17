/// One entry in a game's play-by-play log. Scores and every stat are derived
/// from these events, so undo is simply "delete the last event".
enum EventType {
  ftMade,
  ftMiss,

  /// Inside-the-arc shot: worth 2 (standard) or 1 (streetball 1s & 2s).
  insideMade,
  insideMiss,

  /// Behind-the-arc shot: worth 3 (standard) or 2 (streetball 1s & 2s).
  outsideMade,
  outsideMiss,
  rebound,
  assist,
  steal,
  block,
  turnover,
  foul;

  bool get isShot => index <= EventType.outsideMiss.index;
  bool get isMade => this == ftMade || this == insideMade || this == outsideMade;
  bool get isMiss => this == ftMiss || this == insideMiss || this == outsideMiss;
  bool get isFieldGoal => isShot && this != ftMade && this != ftMiss;
}

class GameEvent {
  GameEvent({
    required this.id,
    required this.gameId,
    required this.team,
    required this.type,
    required this.at,
    this.playerId,
    this.points = 0,
    this.airball = false,
    this.linkedId,
    this.clockMs,
  });

  final String id;
  final String gameId;

  /// 0 or 1: index into [Game.teams].
  final int team;

  /// Null when credited to the team only (quick scoring without a player).
  final String? playerId;
  final EventType type;

  /// Points scored by this event (0 for non-scoring events). Stored at the
  /// time of the event so rule changes never rewrite history.
  final int points;
  final bool airball;

  /// For assists/rebounds: the shot event they belong to (undo removes both).
  final String? linkedId;
  final DateTime at;

  /// Game clock remaining (ms) when the event happened, if a clock was used.
  final int? clockMs;

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameId': gameId,
        'team': team,
        'playerId': playerId,
        'type': type.name,
        'points': points,
        if (airball) 'airball': true,
        if (linkedId != null) 'linkedId': linkedId,
        'at': at.toIso8601String(),
        if (clockMs != null) 'clockMs': clockMs,
      };

  factory GameEvent.fromJson(Map<String, dynamic> j) => GameEvent(
        id: j['id'] as String,
        gameId: j['gameId'] as String,
        team: (j['team'] as num).toInt(),
        playerId: j['playerId'] as String?,
        type: EventType.values.byName(j['type'] as String),
        points: (j['points'] as num?)?.toInt() ?? 0,
        airball: j['airball'] as bool? ?? false,
        linkedId: j['linkedId'] as String?,
        at: DateTime.parse(j['at'] as String),
        clockMs: (j['clockMs'] as num?)?.toInt(),
      );
}
