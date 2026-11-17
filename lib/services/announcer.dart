import 'dart:math';

import '../models/game.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import 'sound_service.dart';

/// Something for the announcer to say: recorded-clip keys (most specific
/// first) plus the text the phone voice reads if no clip exists.
class Call {
  const Call(this.keys, this.text, {this.player});
  final List<String> keys;
  final String text;

  /// Player being called, so their personal clips ("Jay for three!") can play.
  final Player? player;
}

/// Decides which sound and which announcer call go with a play.
class Announcer {
  Announcer([Random? rng]) : _rng = rng ?? Random();
  final Random _rng;

  /// Share of plain inside buckets that get a call (big plays always do).
  static const bucketCallChance = 0.35;

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

  /// Call for a play, or null to stay quiet (so the announcer doesn't talk all game).
  Call? callFor(GameEvent e, Player? p, GameRules rules) {
    final n = p?.displayName;
    if (e.airball) {
      return Call(['airball'], n != null ? 'Air ball! Come on, $n!' : 'Air ball!', player: p);
    }
    switch (e.type) {
      case EventType.outsideMade:
        final streetball = rules.scoring == ScoringMode.streetball;
        return Call(
          streetball ? ['deep', 'three'] : ['three'],
          n != null ? (streetball ? '$n from deep!' : '$n for three!') : 'From downtown!',
          player: p,
        );
      case EventType.insideMade:
        if (_rng.nextDouble() >= bucketCallChance) return null;
        return Call(['bucket'], n != null ? '$n scores!' : 'Bucket!', player: p);
      case EventType.block:
        return Call(['block'], n != null ? '$n with the block!' : 'Rejected!', player: p);
      case EventType.steal:
        return Call(['steal'], n != null ? '$n with the steal!' : 'Stolen!', player: p);
      case EventType.foul:
        return Call(['foul'], n != null ? 'Foul on $n' : 'Foul!', player: p);
      default:
        return null;
    }
  }

  /// "black" for a team named after a shirt color, else null.
  static String? colorKey(TeamSide t) {
    final name = t.name.trim().toLowerCase();
    for (final (preset, _) in teamColorPresets) {
      if (preset.toLowerCase() == name) return name;
    }
    return null;
  }

  Call tipOff(Game g) => Call(
        ['tipoff'],
        'Game ${g.number}. ${g.teams[0].name} versus ${g.teams[1].name}. Let\'s go!',
      );

  Call gamePoint(TeamSide team) {
    final c = colorKey(team);
    return Call([if (c != null) 'gamepoint_$c', 'gamepoint'], 'Game point, ${team.name}!');
  }

  Call gameOver(Game g, List<int> scores) {
    if (scores[0] == scores[1]) {
      return Call(['gameover'], 'That\'s the game! It\'s a tie, ${scores[0]} all!');
    }
    final w = scores[0] > scores[1] ? 0 : 1;
    final hi = scores[w], lo = scores[1 - w];
    final c = colorKey(g.teams[w]);
    // Mix "Black wins it!" with "That's the ballgame!" so it stays fresh.
    final keys = [if (c != null && _rng.nextDouble() < 0.6) 'win_$c', 'gameover'];
    return Call(keys, _pick([
      'That\'s the game! ${g.teams[w].name} wins, $hi to $lo!',
      'Game over! ${g.teams[w].name} takes it, $hi to $lo!',
    ]));
  }
}
