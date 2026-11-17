import 'dart:math';

import '../logic/scoring.dart';
import '../logic/team_balancer.dart';
import '../models/game.dart';
import '../models/game_day.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import 'app_store.dart';

/// Fills the app with a sample crew and a few weeks of simulated runs, so
/// every screen can be explored before the real group is entered.
class DemoData {
  static const _roster = <(String, String?, int, String, int, int, String, List<int>, List<String>, List<String>)>[
    // name, nickname, #, positions, cm, kg, hand, [SHT FIN PLY DEF REB ATH], strengths, weaknesses
    ('Jay Park', 'J-Splash', 30, 'G', 180, 74, 'R', [9, 6, 7, 5, 4, 6], ['3PT shooting', 'Free throws'], ['Perimeter D']),
    ('Danny Kim', 'Big D', 34, 'C', 193, 98, 'R', [3, 8, 4, 8, 9, 6], ['Rim protection', 'Rebounding'], ['Free throws', 'Speed']),
    ('Chris Lee', null, 3, 'G', 175, 70, 'L', [7, 7, 9, 6, 4, 8], ['Ball handling', 'Court vision', 'Left hand'], ['Rebounding']),
    ('Sam Choi', 'Sammy', 11, 'GF', 183, 80, 'R', [6, 7, 6, 7, 6, 7], ['Hustle', 'Perimeter D'], ['Mid-range']),
    ('Tony Han', null, 21, 'F', 188, 88, 'R', [5, 8, 5, 6, 7, 7], ['Post moves', 'Finishing'], ['3PT shooting']),
    ('Kevin Oh', 'KO', 7, 'G', 172, 68, 'R', [6, 5, 7, 8, 3, 9], ['Speed', 'Perimeter D'], ['Finishing', 'Rebounding']),
    ('Brian Jung', null, 15, 'FC', 191, 92, 'R', [4, 7, 4, 7, 8, 5], ['Rebounding', 'Hustle'], ['Ball handling']),
    ('Eric Song', 'E-Money', 0, 'G', 178, 72, 'R', [8, 6, 6, 4, 4, 6], ['Mid-range', '3PT shooting'], ['Perimeter D', 'Stamina']),
    ('James Yoo', null, 23, 'F', 186, 84, 'L', [6, 6, 6, 6, 6, 6], ['Basketball IQ', 'Left hand'], ['Speed']),
    ('Alex Kang', 'AK', 9, 'GF', 181, 77, 'R', [5, 6, 8, 6, 5, 7], ['Passing', 'Leadership'], ['3PT shooting']),
    ('Ryan Shin', null, 44, 'C', 196, 102, 'R', [2, 7, 3, 7, 9, 4], ['Rim protection'], ['Stamina', 'Free throws']),
    ('Steve Moon', 'Moonshot', 33, 'F', 184, 82, 'R', [7, 5, 5, 5, 5, 5], ['3PT shooting', 'Trash talk'], ['Perimeter D']),
  ];

  static void seed(AppStore store, {Random? random, DateTime? now}) {
    final rng = random ?? Random(7);
    final today = now ?? DateTime.now();
    final players = <Player>[];
    for (var i = 0; i < _roster.length; i++) {
      final r = _roster[i];
      final p = Player(
        id: newId(),
        name: r.$1,
        nickname: r.$2,
        jerseyNumber: r.$3,
        positions: {
          for (final c in r.$4.split(''))
            switch (c) {
              'G' => Position.guard,
              'F' => Position.forward,
              _ => Position.center,
            },
        },
        heightCm: r.$5.toDouble(),
        weightKg: r.$6.toDouble(),
        hand: r.$7,
        ratings: {for (var a = 0; a < Attribute.values.length; a++) Attribute.values[a]: r.$8[a]},
        strengths: r.$9,
        weaknesses: r.$10,
        colorValue: avatarColors[i % avatarColors.length].toARGB32(),
      );
      players.add(p);
      store.savePlayer(p);
    }

    for (var week = 5; week >= 1; week--) {
      final day = DateTime(today.year, today.month, today.day - 7 * week, 19);
      final attendees = [...players]..shuffle(rng);
      final present = attendees.take(10 + rng.nextInt(3)).toList();
      final gd = GameDay(
        id: newId(),
        date: day,
        location: 'Community Center Gym',
        attendeeIds: present.map((p) => p.id).toList(),
      );
      store.saveGameDay(gd);
      final streetball = week == 3;
      var clock = day;
      final played = <String, int>{};
      for (var n = 1; n <= 3; n++) {
        final order = [...present]..shuffle(rng);
        order.sort((a, b) => (played[a.id] ?? 0).compareTo(played[b.id] ?? 0));
        final split = TeamBalancer.balance(order.take(10).toList(), rng);
        for (final id in split.expand((t) => t)) {
          played[id] = (played[id] ?? 0) + 1;
        }
        final rules = GameRules(
          scoring: streetball ? ScoringMode.streetball : ScoringMode.standard,
          targetScore: streetball ? 15 : 21,
        );
        final colors = [teamColorPresets[1], teamColorPresets[0]];
        final game = Game(
          id: newId(),
          gameDayId: gd.id,
          number: n,
          teams: [
            for (var t = 0; t < 2; t++)
              TeamSide(name: colors[t].$1, colorValue: colors[t].$2.toARGB32(), playerIds: split[t]),
          ],
          rules: rules,
          status: GameStatus.finished,
          createdAt: clock,
          startedAt: clock,
        );
        final byId = {for (final p in players) p.id: p};
        clock = _simulate(store, game, byId, rng, clock);
        game.endedAt = clock;
        store.saveGame(game);
        clock = clock.add(Duration(minutes: 4 + rng.nextInt(5)));
      }
    }
  }

  static T _weighted<T>(List<T> items, double Function(T) w, Random rng) {
    final weights = items.map(w).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var i = 0; i < items.length; i++) {
      r -= weights[i];
      if (r <= 0) return items[i];
    }
    return items.last;
  }

  /// Possession-by-possession simulation driven by player ratings.
  static DateTime _simulate(AppStore store, Game game, Map<String, Player> byId, Random rng, DateTime start) {
    var t = start;
    var offense = rng.nextInt(2);
    final scores = [0, 0];
    int rating(Player p, Attribute a) => p.ratings[a] ?? 5;
    final rules = game.rules;

    GameEvent ev(int team, Player? p, EventType type, {String? linked, bool airball = false}) {
      t = t.add(Duration(seconds: 2 + rng.nextInt(4)));
      final e = GameEvent(
        id: newId(),
        gameId: game.id,
        team: team,
        playerId: p?.id,
        type: type,
        points: rules.pointsFor(type),
        airball: airball,
        linkedId: linked,
        at: t,
      );
      store.addEvent(e);
      scores[team] += e.points;
      return e;
    }

    for (var guard = 0; guard < 500 && !targetReached(rules, scores); guard++) {
      t = t.add(Duration(seconds: 10 + rng.nextInt(18)));
      final off = game.teams[offense].playerIds.map((id) => byId[id]!).toList();
      final def = game.teams[1 - offense].playerIds.map((id) => byId[id]!).toList();
      final r = rng.nextDouble();

      if (r < 0.10) {
        final loser = _weighted<Player>(off, (p) => 11.0 - rating(p, Attribute.playmaking), rng);
        ev(offense, loser, EventType.turnover);
        if (rng.nextBool()) {
          ev(1 - offense, _weighted<Player>(def, (p) => (rating(p, Attribute.defense) + rating(p, Attribute.athleticism)).toDouble(), rng), EventType.steal);
        }
        offense = 1 - offense;
        continue;
      }
      if (r < 0.15) {
        final fouler = _weighted<Player>(def, (p) => 11.0 - rating(p, Attribute.defense) / 2, rng);
        ev(1 - offense, fouler, EventType.foul);
        if (rules.scoring == ScoringMode.standard && rng.nextDouble() < 0.6) {
          final shooter = _weighted<Player>(off, (p) => rating(p, Attribute.finishing).toDouble(), rng);
          for (var k = 0; k < 2; k++) {
            final make = rng.nextDouble() < 0.55 + 0.04 * (rating(shooter, Attribute.shooting) - 5);
            ev(offense, shooter, make ? EventType.ftMade : EventType.ftMiss);
          }
          offense = 1 - offense;
        }
        continue;
      }

      final shooter = _weighted<Player>(off, (p) => pow(rating(p, Attribute.shooting) + rating(p, Attribute.finishing), 1.6).toDouble(), rng);
      final outside = rng.nextDouble() < (0.12 + 0.05 * (rating(shooter, Attribute.shooting) - 4)).clamp(0.04, 0.55);
      final makeP = outside
          ? 0.30 + 0.035 * (rating(shooter, Attribute.shooting) - 5)
          : 0.47 + 0.035 * (rating(shooter, Attribute.finishing) - 5);
      if (rng.nextDouble() < makeP) {
        final shot = ev(offense, shooter, outside ? EventType.outsideMade : EventType.insideMade);
        final mates = off.where((p) => p.id != shooter.id).toList();
        if (mates.isNotEmpty && rng.nextDouble() < 0.55) {
          ev(offense, _weighted<Player>(mates, (p) => pow(rating(p, Attribute.playmaking), 2).toDouble(), rng), EventType.assist,
              linked: shot.id);
        }
        offense = 1 - offense;
      } else {
        final airball = outside && rng.nextDouble() < 0.05;
        final shot = ev(offense, shooter, outside ? EventType.outsideMiss : EventType.insideMiss, airball: airball);
        if (!outside && rng.nextDouble() < 0.12) {
          ev(1 - offense, _weighted<Player>(def, (p) => pow(rating(p, Attribute.defense) + rating(p, Attribute.rebounding), 2).toDouble(), rng),
              EventType.block,
              linked: shot.id);
        }
        final offensiveBoard = rng.nextDouble() < 0.28;
        final team = offensiveBoard ? offense : 1 - offense;
        final pool = offensiveBoard ? off : def;
        ev(team, _weighted<Player>(pool, (p) => pow(rating(p, Attribute.rebounding), 2).toDouble(), rng), EventType.rebound,
            linked: shot.id);
        if (!offensiveBoard) offense = 1 - offense;
      }
    }
    return t.add(const Duration(seconds: 15));
  }
}
