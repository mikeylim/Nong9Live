import '../models/game.dart';
import '../models/game_event.dart';

/// Points per team, derived from the play-by-play.
List<int> teamScores(List<GameEvent> events) {
  final s = [0, 0];
  for (final e in events) {
    if (e.points > 0 && e.team >= 0 && e.team < 2) s[e.team] += e.points;
  }
  return s;
}

List<int> teamFouls(List<GameEvent> events) {
  final f = [0, 0];
  for (final e in events) {
    if (e.type == EventType.foul && e.team >= 0 && e.team < 2) f[e.team]++;
  }
  return f;
}

/// Index of the leading team, or null when tied.
int? leaderIndex(List<int> scores) {
  if (scores[0] == scores[1]) return null;
  return scores[0] > scores[1] ? 0 : 1;
}

/// Winner of a finished game (null for live games and ties).
int? winnerIndex(Game game, List<GameEvent> events) {
  if (!game.isFinished) return null;
  return leaderIndex(teamScores(events));
}

/// True when a "first to N" target has been hit (respecting win-by-two).
bool targetReached(GameRules rules, List<int> scores) {
  final target = rules.targetScore;
  if (target == null) return false;
  final hi = scores[0] > scores[1] ? scores[0] : scores[1];
  final lo = scores[0] > scores[1] ? scores[1] : scores[0];
  if (hi < target) return false;
  return !rules.winByTwo || hi - lo >= 2;
}
