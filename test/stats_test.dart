import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nong9live/data/app_store.dart';
import 'package:nong9live/data/demo_data.dart';
import 'package:nong9live/logic/scoring.dart';
import 'package:nong9live/logic/stats.dart';
import 'package:nong9live/logic/team_balancer.dart';
import 'package:nong9live/models/game.dart';
import 'package:nong9live/models/game_event.dart';
import 'package:nong9live/models/player.dart';

import 'helpers.dart';

void main() {
  late AppStore store;
  late StatsEngine stats;

  setUp(() async {
    store = await freshStore();
    stats = StatsEngine(store);
  });

  test('rules: point values per scoring mode', () {
    final std = GameRules();
    final street = GameRules(scoring: ScoringMode.streetball);
    expect([std.pointsFor(EventType.ftMade), std.pointsFor(EventType.insideMade), std.pointsFor(EventType.outsideMade)],
        [1, 2, 3]);
    expect([street.pointsFor(EventType.insideMade), street.pointsFor(EventType.outsideMade)], [1, 2]);
    expect(std.pointsFor(EventType.outsideMiss), 0);
    expect(std.pointsFor(EventType.rebound), 0);
  });

  test('target score and win-by-two', () {
    final r = GameRules(targetScore: 21);
    expect(targetReached(r, [20, 19]), isFalse);
    expect(targetReached(r, [21, 20]), isTrue);
    expect(targetReached(r, [22, 5]), isTrue);
    r.winByTwo = true;
    expect(targetReached(r, [21, 20]), isFalse);
    expect(targetReached(r, [22, 20]), isTrue);
    expect(targetReached(GameRules(), [100, 0]), isFalse);
  });

  group('one game', () {
    late Player jay, danny, chris, sam;
    late Game game;
    late Scorer s;

    setUp(() {
      jay = addPlayer(store, 'Jay Park');
      danny = addPlayer(store, 'Danny Kim');
      chris = addPlayer(store, 'Chris Lee');
      sam = addPlayer(store, 'Sam Choi');
      final day = store.createGameDay(date: DateTime(2026, 11, 17), attendeeIds: [jay.id, danny.id, chris.id, sam.id]);
      game = store.createGame(
        gameDayId: day.id,
        teams: [
          TeamSide(name: 'Black', colorValue: 0xFF000000, playerIds: [jay.id, danny.id]),
          TeamSide(name: 'White', colorValue: 0xFFFFFFFF, playerIds: [chris.id, sam.id]),
        ],
        rules: GameRules(targetScore: 11),
      );
      s = Scorer(store, game);
    });

    test('box score adds up and the winner gets the W', () {
      final three = s.log(jay, EventType.outsideMade);
      s.log(danny, EventType.assist, linkedId: three.id);
      s.log(jay, EventType.insideMade);
      s.log(danny, EventType.insideMiss);
      s.log(danny, EventType.rebound);
      s.log(danny, EventType.insideMade);
      s.log(chris, EventType.outsideMiss, airball: true);
      s.log(sam, EventType.rebound);
      s.log(sam, EventType.ftMade);
      s.log(sam, EventType.ftMiss);
      s.log(chris, EventType.foul);
      s.log(null, EventType.insideMade, team: 1); // team-only bucket
      s.log(sam, EventType.block);
      s.log(chris, EventType.steal);
      s.log(chris, EventType.turnover);
      store.finishGame(game);

      final box = stats.boxScore(game);
      expect(box.scores, [7, 3]);
      expect(box.winner, 0);
      final j = box.lineFor(jay.id)!;
      expect([j.pts, j.fgm, j.fga, j.outM, j.outA], [5, 2, 2, 1, 1]);
      final d = box.lineFor(danny.id)!;
      expect([d.pts, d.reb, d.ast, d.fgm, d.fga], [2, 1, 1, 1, 2]);
      final c = box.lineFor(chris.id)!;
      expect([c.airballs, c.outA, c.pf, c.stl, c.tov], [1, 1, 1, 1, 1]);
      final sm = box.lineFor(sam.id)!;
      expect([sm.pts, sm.ftm, sm.fta, sm.reb, sm.blk], [1, 1, 2, 1, 1]);
      // Team totals include the unattributed bucket.
      expect(box.teamTotals[1].pts, 3);
      expect(j.wins + d.wins, 2);
      expect(c.losses + sm.losses, 2);
      expect(box.mvpId, jay.id);
    });

    test('undo removes the shot together with its assist', () {
      s.log(jay, EventType.insideMade);
      final shot = s.log(jay, EventType.outsideMade);
      s.log(danny, EventType.assist, linkedId: shot.id);
      expect(teamScores(store.eventsFor(game.id)), [5, 0]);

      final undone = store.undoLast(game.id);
      expect(undone?.id, shot.id);
      final left = store.eventsFor(game.id);
      expect(left, hasLength(1));
      expect(teamScores(left), [2, 0]);
      expect(stats.boxScore(game).lineFor(danny.id)!.ast, 0);
    });

    test('career, leaders, streaks and teammates across games', () {
      // Game 1: Black wins.
      s.log(jay, EventType.outsideMade);
      store.finishGame(game);
      // Game 2: same teams, Black wins again.
      final g2 = store.createGame(gameDayId: game.gameDayId, teams: game.teams.map((t) => t.copy()).toList(), rules: GameRules());
      final s2 = Scorer(store, g2, start: DateTime(2026, 11, 17, 20));
      s2.log(jay, EventType.insideMade);
      s2.log(danny, EventType.rebound);
      store.finishGame(g2);
      // A live game does not count yet.
      final g3 = store.createGame(gameDayId: game.gameDayId, teams: game.teams.map((t) => t.copy()).toList(), rules: GameRules());
      Scorer(store, g3, start: DateTime(2026, 11, 17, 21)).log(chris, EventType.outsideMade);

      final career = stats.career(jay.id);
      expect([career.gp, career.wins, career.losses, career.pts], [2, 2, 0, 5]);
      expect(stats.career(chris.id).pts, 0);
      expect(stats.streak(jay.id), 'W2');
      expect(stats.streak(chris.id), 'L2');

      final leaders = stats.leaders(StatCategory.points, minGames: 1);
      expect(leaders.first.player.id, jay.id);
      expect(leaders.first.value, 2.5);

      final mates = stats.teammates(jay.id);
      expect(mates.single.player.id, danny.id);
      expect(mates.single.winPct, 1.0);

      final day = stats.dayTotals(game.gameDayId);
      expect(day[jay.id]!.gp, 2);
      expect(stats.dayMvp(game.gameDayId), jay.id);
    });

    test('backup round-trips everything', () async {
      final shot = s.log(jay, EventType.outsideMade);
      s.log(danny, EventType.assist, linkedId: shot.id);
      store.finishGame(game);
      store.settings.crewName = 'Tuesday Hoops';
      store.saveSettings();
      final json = jsonDecode(jsonEncode(store.toBackup())) as Map<String, dynamic>;

      await store.clearAll();
      expect(store.allPlayers, isEmpty);

      await store.restoreBackup(json);
      expect(store.allPlayers, hasLength(4));
      expect(store.settings.crewName, 'Tuesday Hoops');
      final restored = store.game(game.id)!;
      expect(restored.isFinished, isTrue);
      expect(StatsEngine(store).boxScore(restored).scores, [3, 0]);
      expect(() => store.restoreBackup({'format': 'nope'}), throwsFormatException);
    });
  });

  test('archiving keeps players who have games; deleting removes others', () {
    final a = addPlayer(store, 'A');
    final b = addPlayer(store, 'B');
    final day = store.createGameDay(date: DateTime.now(), attendeeIds: [a.id, b.id]);
    store.createGame(
      gameDayId: day.id,
      teams: [TeamSide(name: 'X', colorValue: 0, playerIds: [a.id]), TeamSide(name: 'Y', colorValue: 0)],
      rules: GameRules(),
    );
    store.deletePlayer(a.id);
    store.deletePlayer(b.id);
    expect(store.player(a.id)?.archived, isTrue);
    expect(store.player(b.id), isNull);
    expect(store.gameDay(day.id)!.attendeeIds, [a.id]);
  });

  group('team balancer', () {
    List<Player> roster(List<int> skill) => [
          for (var i = 0; i < skill.length; i++)
            Player(
              id: 'p$i',
              name: 'P$i',
              ratings: {for (final a in Attribute.values) a: skill[i]},
              positions: {Position.values[i % 3]},
            ),
        ];

    test('splits evenly by count and strength', () {
      final players = roster([10, 9, 8, 7, 6, 5, 4, 3, 2, 1]);
      for (var seed = 0; seed < 20; seed++) {
        final teams = TeamBalancer.balance(players, Random(seed));
        expect(teams[0].length, 5);
        expect(teams[1].length, 5);
        expect({...teams[0], ...teams[1]}, hasLength(10));
        double sum(List<String> ids) => ids.map((id) => players.firstWhere((p) => p.id == id).strength).reduce((a, b) => a + b);
        expect((sum(teams[0]) - sum(teams[1])).abs(), lessThanOrEqualTo(1.0));
      }
    });

    test('handles odd counts and tiny rosters', () {
      final t = TeamBalancer.balance(roster([5, 5, 5, 5, 5, 5, 5]), Random(1));
      expect([t[0].length, t[1].length], [4, 3]);
      expect(TeamBalancer.balance(roster([5]), Random(1))[0], ['p0']);
      final r = TeamBalancer.random(roster([1, 2, 3, 4]), Random(3));
      expect([r[0].length, r[1].length], [2, 2]);
    });

    test('balanced splits still vary week to week', () {
      final players = roster([6, 6, 6, 6, 6, 6, 6, 6, 6, 6]);
      final seen = <String>{};
      for (var seed = 0; seed < 10; seed++) {
        seen.add((TeamBalancer.balance(players, Random(seed))[0]..sort()).join(','));
      }
      expect(seen.length, greaterThan(1));
    });
  });

  test('demo data simulates complete, consistent games', () {
    DemoData.seed(store, random: Random(42), now: DateTime(2026, 11, 17));
    expect(store.players, hasLength(12));
    expect(store.gameDays, hasLength(5));
    final games = store.allGames;
    expect(games, hasLength(15));
    for (final g in games) {
      expect(g.isFinished, isTrue);
      final box = stats.boxScore(g);
      expect(targetReached(g.rules, box.scores), isTrue, reason: '${g.title} ${box.scores}');
      expect(box.winner, isNotNull);
      for (var t = 0; t < 2; t++) {
        final playerPts = box.players[t].values.fold<int>(0, (s, l) => s + l.pts);
        expect(playerPts, box.scores[t]);
      }
    }
    expect(stats.leaders(StatCategory.points), isNotEmpty);
    expect(stats.records(), isNotEmpty);
  });
}
