import 'dart:math';

import '../models/player.dart';

/// Splits players into two teams.
class TeamBalancer {
  /// Purely random split (sizes differ by at most one).
  static List<List<String>> random(List<Player> players, Random rng) {
    final shuffled = [...players]..shuffle(rng);
    final half = (shuffled.length + 1) ~/ 2;
    return [
      shuffled.take(half).map((p) => p.id).toList(),
      shuffled.skip(half).map((p) => p.id).toList(),
    ];
  }

  /// Balanced split: minimizes the difference in total strength while
  /// spreading guards / bigs evenly. Many randomized hill-climbing restarts
  /// are run and one of the near-best splits is picked, so you get fair
  /// teams that still change from week to week.
  static List<List<String>> balance(
    List<Player> players,
    Random rng, {
    double Function(Player)? strengthOf,
    int restarts = 120,
  }) {
    if (players.length < 2) return [players.map((p) => p.id).toList(), <String>[]];
    final strength = strengthOf ?? (Player p) => p.strength;
    final n = players.length;
    final sizeA = (n + 1) ~/ 2;
    final s = [for (final p in players) strength(p)];
    final pos = [for (final p in players) p.primaryPosition];

    double cost(List<bool> inA) {
      var sumA = 0.0, sumB = 0.0;
      final posA = <Position?, int>{}, posB = <Position?, int>{};
      for (var i = 0; i < n; i++) {
        if (inA[i]) {
          sumA += s[i];
          posA[pos[i]] = (posA[pos[i]] ?? 0) + 1;
        } else {
          sumB += s[i];
          posB[pos[i]] = (posB[pos[i]] ?? 0) + 1;
        }
      }
      var posPenalty = 0;
      for (final p in Position.values) {
        posPenalty += ((posA[p] ?? 0) - (posB[p] ?? 0)).abs();
      }
      return (sumA - sumB).abs() + 0.35 * max(0, posPenalty - n % 2);
    }

    final results = <(double, List<bool>)>[];
    for (var r = 0; r < restarts; r++) {
      final order = List.generate(n, (i) => i)..shuffle(rng);
      final inA = List<bool>.filled(n, false);
      for (var i = 0; i < sizeA; i++) {
        inA[order[i]] = true;
      }
      var current = cost(inA);
      var improved = true;
      while (improved) {
        improved = false;
        for (var i = 0; i < n && !improved; i++) {
          if (!inA[i]) continue;
          for (var j = 0; j < n; j++) {
            if (inA[j]) continue;
            inA[i] = false;
            inA[j] = true;
            final c = cost(inA);
            if (c < current - 1e-9) {
              current = c;
              improved = true;
              break;
            }
            inA[i] = true;
            inA[j] = false;
          }
        }
      }
      results.add((current, [...inA]));
    }
    results.sort((a, b) => a.$1.compareTo(b.$1));
    final best = results.first.$1;
    final near = results.where((r) => r.$1 <= best + 0.25).toList();
    final pick = near[rng.nextInt(near.length)].$2;
    return [
      [for (var i = 0; i < n; i++) if (pick[i]) players[i].id],
      [for (var i = 0; i < n; i++) if (!pick[i]) players[i].id],
    ];
  }

  static double totalStrength(Iterable<Player> players) =>
      players.fold<double>(0, (sum, p) => sum + p.strength);
}
