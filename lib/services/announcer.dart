import 'dart:math';

import '../models/game.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import 'sound_service.dart';

/// Decides which sound and (optionally) which spoken line goes with a play.
class Announcer {
  Announcer([Random? rng]) : _rng = rng ?? Random();
  final Random _rng;

  String _pick(List<String> options) => options[_rng.nextInt(options.length)];

  Sfx? sfxFor(GameEvent e) {
    if (e.airball) return Sfx.airball;
    return switch (e.type) {
      EventType.ftMade => Sfx.score1,
      EventType.insideMade => Sfx.score2,
      EventType.outsideMade => Sfx.score3,
      EventType.ftMiss || EventType.insideMiss || EventType.outsideMiss => Sfx.brick,
      EventType.block => Sfx.block,
      EventType.steal => Sfx.steal,
      EventType.foul => Sfx.whistle,
      EventType.turnover => Sfx.whistleDouble,
      _ => null,
    };
  }

  /// Spoken line for big plays only, so the announcer doesn't talk all game.
  String? lineFor(GameEvent e, Player? p, GameRules rules) {
    final n = p?.displayName;
    if (e.airball) {
      return _pick([
        'Air ball!',
        'Air... ball!',
        if (n != null) 'Air ball! Come on, $n!',
      ]);
    }
    switch (e.type) {
      case EventType.outsideMade:
        if (rules.scoring == ScoringMode.streetball) {
          return _pick([
            n != null ? '$n from deep!' : 'From deep!',
            'Splash!',
            n != null ? 'Bang! $n!' : 'Bang!',
          ]);
        }
        return _pick([
          n != null ? '$n for three!' : 'Three pointer!',
          n != null ? 'Bang! $n from downtown!' : 'Bang! From downtown!',
          n != null ? '$n... splash!' : 'Splash!',
          'From way downtown!',
        ]);
      case EventType.block:
        return _pick([
          'Rejected!',
          'Get that outta here!',
          if (n != null) '$n with the block!',
          'Not in my house!',
        ]);
      case EventType.steal:
        return _pick([
          if (n != null) '$n with the steal!',
          'Picked his pocket!',
          'Stolen!',
        ]);
      case EventType.foul:
        return n != null ? 'Foul on $n' : 'Foul!';
      default:
        return null;
    }
  }

  String tipOff(Game g) =>
      'Game ${g.number}. ${g.teams[0].name} versus ${g.teams[1].name}. Let\'s go!';

  String gamePoint(TeamSide team) => 'Game point, ${team.name}!';

  String gameOver(Game g, List<int> scores) {
    if (scores[0] == scores[1]) return 'That\'s the game! It\'s a tie, ${scores[0]} all!';
    final w = scores[0] > scores[1] ? 0 : 1;
    final hi = scores[w], lo = scores[1 - w];
    return _pick([
      'That\'s the game! ${g.teams[w].name} wins, $hi to $lo!',
      'Game over! ${g.teams[w].name} takes it, $hi to $lo!',
    ]);
  }
}
