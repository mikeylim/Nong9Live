import '../models/game.dart';
import '../models/game_event.dart';
import '../models/player.dart';

/// Human-readable play-by-play line, e.g. "Jay hits a three (+3)".
String playText(GameEvent e, Game g, Player? p, {Player? assist}) {
  final who = p?.displayName ?? g.teams[e.team].name;
  final s = g.rules.scoring;
  final text = switch (e.type) {
    EventType.ftMade => '$who makes a free throw',
    EventType.ftMiss => '$who misses a free throw',
    EventType.insideMade => '$who scores inside (+${s.insidePoints})',
    EventType.outsideMade =>
      s == ScoringMode.standard ? '$who hits a three (+3)' : '$who hits from deep (+${s.outsidePoints})',
    EventType.insideMiss => e.airball ? '$who AIRBALL 💨' : '$who misses inside',
    EventType.outsideMiss => e.airball ? '$who AIRBALL from deep 💨' : '$who misses from deep',
    EventType.rebound => '$who rebound',
    EventType.assist => '$who assist',
    EventType.steal => '$who steal',
    EventType.block => '$who BLOCK 🚫',
    EventType.turnover => '$who turnover',
    EventType.foul => 'Foul on $who',
  };
  return assist == null ? text : '$text · ast ${assist.displayName}';
}

/// Short label for an event type (buttons, chips).
String eventShort(EventType t, ScoringMode s) => switch (t) {
      EventType.ftMade => 'FT ✓',
      EventType.ftMiss => 'FT ✗',
      EventType.insideMade => '${s.insideLabel} ✓',
      EventType.insideMiss => '${s.insideLabel} ✗',
      EventType.outsideMade => '${s.outsideLabel} ✓',
      EventType.outsideMiss => '${s.outsideLabel} ✗',
      EventType.rebound => 'REB',
      EventType.assist => 'AST',
      EventType.steal => 'STL',
      EventType.block => 'BLK',
      EventType.turnover => 'TO',
      EventType.foul => 'FOUL',
    };

/// Running score after each event (same order as [events]).
List<List<int>> runningScores(List<GameEvent> events) {
  final s = [0, 0];
  return [
    for (final e in events) [s[0] += e.team == 0 ? e.points : 0, s[1] += e.team == 1 ? e.points : 0],
  ];
}
