import 'package:hive_ce/hive.dart';
import 'package:nong9live/data/app_store.dart';
import 'package:nong9live/models/game.dart';
import 'package:nong9live/models/game_event.dart';
import 'package:nong9live/models/player.dart';

/// Fresh in-memory store for each test.
Future<AppStore> freshStore() async {
  await Hive.close();
  return AppStore.open(inMemory: true);
}

Player addPlayer(AppStore s, String name, {Map<Attribute, int>? ratings, Set<Position>? positions}) {
  final p = Player(id: newId(), name: name, ratings: ratings, positions: positions);
  s.savePlayer(p);
  return p;
}

/// Small helper to log plays with increasing timestamps.
class Scorer {
  Scorer(this.store, this.game, {DateTime? start}) : _t = start ?? DateTime(2026, 11, 17, 19);
  final AppStore store;
  final Game game;
  DateTime _t;

  GameEvent log(Player? p, EventType type, {int? team, bool airball = false, String? linkedId}) {
    _t = _t.add(const Duration(seconds: 20));
    final e = GameEvent(
      id: newId(),
      gameId: game.id,
      team: team ?? (p == null ? 0 : game.teamIndexOf(p.id)!),
      playerId: p?.id,
      type: type,
      points: game.rules.pointsFor(type),
      airball: airball,
      linkedId: linkedId,
      at: _t,
    );
    store.addEvent(e);
    return e;
  }
}
