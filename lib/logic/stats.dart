import '../data/app_store.dart';
import '../models/game.dart';
import '../models/game_day.dart';
import '../models/game_event.dart';
import '../models/player.dart';
import 'scoring.dart';

/// Accumulated box-score numbers (one game, a day, or a whole career).
class StatLine {
  int gp = 0, wins = 0, losses = 0;
  int pts = 0, ftm = 0, fta = 0, inM = 0, inA = 0, outM = 0, outA = 0;
  int reb = 0, ast = 0, stl = 0, blk = 0, tov = 0, pf = 0, airballs = 0;

  int get fgm => inM + outM;
  int get fga => inA + outA;

  static double? _pct(int m, int a) => a == 0 ? null : m / a;
  double? get fgPct => _pct(fgm, fga);
  double? get outPct => _pct(outM, outA);
  double? get ftPct => _pct(ftm, fta);
  double? get winPct => wins + losses == 0 ? null : wins / (wins + losses);

  bool get isEmpty =>
      pts == 0 && fga == 0 && fta == 0 && reb == 0 && ast == 0 && stl == 0 && blk == 0 && tov == 0 && pf == 0;

  double per(num v) => gp == 0 ? 0 : v / gp;

  /// Simplified Hollinger Game Score: one number for "how good was that".
  double get gameScore =>
      pts + 0.4 * fgm - 0.7 * fga - 0.4 * (fta - ftm) + 0.5 * reb + stl + 0.7 * ast + 0.7 * blk - 0.4 * pf - tov;

  void add(GameEvent e) {
    pts += e.points;
    switch (e.type) {
      case EventType.ftMade:
        ftm++;
        fta++;
      case EventType.ftMiss:
        fta++;
      case EventType.insideMade:
        inM++;
        inA++;
      case EventType.insideMiss:
        inA++;
      case EventType.outsideMade:
        outM++;
        outA++;
      case EventType.outsideMiss:
        outA++;
      case EventType.rebound:
        reb++;
      case EventType.assist:
        ast++;
      case EventType.steal:
        stl++;
      case EventType.block:
        blk++;
      case EventType.turnover:
        tov++;
      case EventType.foul:
        pf++;
    }
    if (e.airball) airballs++;
  }

  void merge(StatLine o) {
    gp += o.gp;
    wins += o.wins;
    losses += o.losses;
    pts += o.pts;
    ftm += o.ftm;
    fta += o.fta;
    inM += o.inM;
    inA += o.inA;
    outM += o.outM;
    outA += o.outA;
    reb += o.reb;
    ast += o.ast;
    stl += o.stl;
    blk += o.blk;
    tov += o.tov;
    pf += o.pf;
    airballs += o.airballs;
  }
}

enum GameResult { win, loss, tie }

class BoxScore {
  BoxScore({
    required this.game,
    required this.scores,
    required this.players,
    required this.teamTotals,
    required this.winner,
    required this.mvpId,
  });

  final Game game;
  final List<int> scores;

  /// Per team: playerId -> line, in roster order.
  final List<Map<String, StatLine>> players;

  /// Per team totals including team-only (unattributed) events.
  final List<StatLine> teamTotals;
  final int? winner;
  final String? mvpId;

  StatLine? lineFor(String playerId) {
    for (final t in players) {
      final l = t[playerId];
      if (l != null) return l;
    }
    return null;
  }

  GameResult? resultFor(int team) {
    if (!game.isFinished) return null;
    if (winner == null) return GameResult.tie;
    return winner == team ? GameResult.win : GameResult.loss;
  }
}

class PlayerGameLine {
  PlayerGameLine(this.game, this.day, this.team, this.line, this.result, this.score);
  final Game game;
  final GameDay? day;
  final int team;
  final StatLine line;
  final GameResult? result;
  final List<int> score;

  DateTime get when => game.startedAt ?? day?.date ?? game.createdAt;
}

enum StatsRange {
  allTime('All time'),
  thisYear('This year'),
  last30('Last 30 days');

  const StatsRange(this.label);
  final String label;

  bool includes(DateTime d, DateTime now) => switch (this) {
        StatsRange.allTime => true,
        StatsRange.thisYear => d.year == now.year,
        StatsRange.last30 => now.difference(d).inDays <= 30,
      };
}

enum StatCategory {
  points('Points', 'PPG', '🏀'),
  rebounds('Rebounds', 'RPG', '🧲'),
  assists('Assists', 'APG', '🎯'),
  steals('Steals', 'SPG', '🥷'),
  blocks('Blocks', 'BPG', '🚫'),
  winPct('Win %', 'WIN%', '🏆'),
  wins('Wins', 'W', '👑'),
  impact('Impact', 'GmSc', '⚡'),
  fgPct('Field goal %', 'FG%', '🎯'),
  outPct('3-point %', '3P%', '🔥'),
  ftPct('Free throw %', 'FT%', '🧘'),
  games('Games played', 'GP', '📅'),
  airballs('Airballs', 'AIR', '💨'),
  fouls('Fouls', 'PF', '🟨'),
  turnovers('Turnovers', 'TO', '🙈');

  const StatCategory(this.label, this.short, this.emoji);
  final String label;
  final String short;
  final String emoji;

  bool get isPercent => this == fgPct || this == outPct || this == ftPct || this == winPct;
  bool get isTotal => this == wins || this == games;

  /// Leaderboards where "more" is funny rather than good.
  bool get isShame => this == airballs || this == fouls || this == turnovers;

  double? valueOf(StatLine l) => switch (this) {
        points => l.per(l.pts),
        rebounds => l.per(l.reb),
        assists => l.per(l.ast),
        steals => l.per(l.stl),
        blocks => l.per(l.blk),
        winPct => l.winPct,
        wins => l.wins.toDouble(),
        impact => l.per(l.gameScore),
        fgPct => l.fga >= 10 ? l.fgPct : null,
        outPct => l.outA >= 5 ? l.outPct : null,
        ftPct => l.fta >= 5 ? l.ftPct : null,
        games => l.gp.toDouble(),
        airballs => l.airballs.toDouble(),
        fouls => l.per(l.pf),
        turnovers => l.per(l.tov),
      };

  String format(double v) {
    if (isPercent) return '${(v * 100).toStringAsFixed(1)}%';
    if (isTotal || this == airballs) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  String detail(StatLine l) => switch (this) {
        fgPct => '${l.fgm}/${l.fga} FG',
        outPct => '${l.outM}/${l.outA} 3P',
        ftPct => '${l.ftm}/${l.fta} FT',
        winPct || wins => '${l.wins}-${l.losses}',
        airballs => '${l.gp} GP',
        points => '${l.pts} pts · ${l.gp} GP',
        rebounds => '${l.reb} reb · ${l.gp} GP',
        assists => '${l.ast} ast · ${l.gp} GP',
        steals => '${l.stl} stl · ${l.gp} GP',
        blocks => '${l.blk} blk · ${l.gp} GP',
        _ => '${l.gp} GP',
      };
}

class LeaderRow {
  LeaderRow(this.player, this.value, this.line);
  final Player player;
  final double value;
  final StatLine line;
}

class TeammateRow {
  TeammateRow(this.player, this.games, this.wins);
  final Player player;
  final int games;
  final int wins;
  double get winPct => games == 0 ? 0 : wins / games;
}

class GameRecord {
  GameRecord(this.label, this.emoji, this.value, this.player, this.gameLine);
  final String label;
  final String emoji;
  final int value;
  final Player player;
  final PlayerGameLine gameLine;
}

/// Read-only stats over the store, cached until the store changes.
class StatsEngine {
  StatsEngine(this.store);
  final AppStore store;

  int _rev = -1;
  final Map<String, BoxScore> _box = {};
  Map<String, List<PlayerGameLine>>? _logs;

  void _sync() {
    if (_rev != store.revision) {
      _rev = store.revision;
      _box.clear();
      _logs = null;
    }
  }

  BoxScore boxScore(Game g) {
    _sync();
    return _box[g.id] ??= _computeBox(g);
  }

  BoxScore _computeBox(Game g) {
    final events = store.eventsFor(g.id);
    final players = [
      for (final t in g.teams) {for (final id in t.playerIds) id: StatLine()..gp = 1},
    ];
    final totals = [StatLine()..gp = 1, StatLine()..gp = 1];
    for (final e in events) {
      if (e.team < 0 || e.team > 1) continue;
      totals[e.team].add(e);
      final pid = e.playerId;
      if (pid == null) continue;
      // Credit the player even if they were moved between teams mid-game.
      final line = players[e.team][pid] ?? players[1 - e.team][pid];
      if (line != null) {
        line.add(e);
      } else {
        players[e.team][pid] = StatLine()
          ..gp = 1
          ..add(e);
      }
    }
    final scores = teamScores(events);
    final winner = g.isFinished ? leaderIndex(scores) : null;
    if (winner != null) {
      for (var t = 0; t < 2; t++) {
        for (final l in players[t].values) {
          if (t == winner) {
            l.wins = 1;
          } else {
            l.losses = 1;
          }
        }
      }
    }
    return BoxScore(
      game: g,
      scores: scores,
      players: players,
      teamTotals: totals,
      winner: winner,
      mvpId: g.mvpOverrideId ?? _pickMvp(players, winner),
    );
  }

  String? _pickMvp(List<Map<String, StatLine>> players, int? winner) {
    String? best;
    var bestScore = double.negativeInfinity;
    final pool = winner == null ? [...players[0].entries, ...players[1].entries] : players[winner].entries;
    for (final e in pool) {
      if (e.value.isEmpty) continue;
      final s = e.value.gameScore;
      if (s > bestScore) {
        bestScore = s;
        best = e.key;
      }
    }
    return best;
  }

  /// Every finished game each player appeared in, newest first.
  Map<String, List<PlayerGameLine>> get _allLogs {
    _sync();
    if (_logs != null) return _logs!;
    final logs = <String, List<PlayerGameLine>>{};
    for (final g in store.allGames.where((g) => g.isFinished)) {
      final box = boxScore(g);
      final day = store.gameDay(g.gameDayId);
      for (var t = 0; t < 2; t++) {
        for (final entry in box.players[t].entries) {
          (logs[entry.key] ??= []).add(PlayerGameLine(g, day, t, entry.value, box.resultFor(t), box.scores));
        }
      }
    }
    for (final l in logs.values) {
      l.sort((a, b) => b.when.compareTo(a.when));
    }
    return _logs = logs;
  }

  List<PlayerGameLine> gameLog(String playerId, {StatsRange range = StatsRange.allTime, DateTime? now}) {
    final n = now ?? DateTime.now();
    return (_allLogs[playerId] ?? const []).where((l) => range.includes(l.when, n)).toList();
  }

  StatLine career(String playerId, {StatsRange range = StatsRange.allTime, DateTime? now}) {
    final total = StatLine();
    for (final l in gameLog(playerId, range: range, now: now)) {
      total.merge(l.line);
    }
    return total;
  }

  List<LeaderRow> leaders(StatCategory c, {StatsRange range = StatsRange.allTime, int? minGames, DateTime? now}) {
    final min = c.isTotal || c == StatCategory.airballs ? 1 : (minGames ?? store.settings.minGamesForLeaders);
    final rows = <LeaderRow>[];
    for (final p in store.allPlayers) {
      final line = career(p.id, range: range, now: now);
      if (line.gp < min) continue;
      final v = c.valueOf(line);
      if (v == null) continue;
      if (c.isShame && v == 0) continue;
      rows.add(LeaderRow(p, v, line));
    }
    rows.sort((a, b) {
      final cmp = b.value.compareTo(a.value);
      return cmp != 0 ? cmp : b.line.gp.compareTo(a.line.gp);
    });
    return rows;
  }

  /// Win rate with each teammate, best duos first.
  List<TeammateRow> teammates(String playerId, {int minGames = 2}) {
    final games = <String, int>{};
    final wins = <String, int>{};
    for (final l in _allLogs[playerId] ?? const <PlayerGameLine>[]) {
      if (l.result == null) continue;
      for (final mate in l.game.teams[l.team].playerIds) {
        if (mate == playerId) continue;
        games[mate] = (games[mate] ?? 0) + 1;
        if (l.result == GameResult.win) wins[mate] = (wins[mate] ?? 0) + 1;
      }
    }
    final rows = <TeammateRow>[];
    for (final e in games.entries) {
      final p = store.player(e.key);
      if (p == null || e.value < minGames) continue;
      rows.add(TeammateRow(p, e.value, wins[e.key] ?? 0));
    }
    rows.sort((a, b) {
      final c = b.winPct.compareTo(a.winPct);
      return c != 0 ? c : b.games.compareTo(a.games);
    });
    return rows;
  }

  /// e.g. "W3" (three straight wins) or "L2"; null with no decided games.
  String? streak(String playerId) {
    final log = (_allLogs[playerId] ?? const <PlayerGameLine>[])
        .where((l) => l.result == GameResult.win || l.result == GameResult.loss)
        .toList();
    if (log.isEmpty) return null;
    final first = log.first.result;
    var n = 0;
    for (final l in log) {
      if (l.result != first) break;
      n++;
    }
    return '${first == GameResult.win ? 'W' : 'L'}$n';
  }

  /// Best single-game performance for each stat, across everyone.
  List<GameRecord> records({StatsRange range = StatsRange.allTime, DateTime? now}) {
    final defs = <(String, String, int Function(StatLine))>[
      ('Most points', '🏀', (l) => l.pts),
      ('Most threes', '🔥', (l) => l.outM),
      ('Most rebounds', '🧲', (l) => l.reb),
      ('Most assists', '🎯', (l) => l.ast),
      ('Most steals', '🥷', (l) => l.stl),
      ('Most blocks', '🚫', (l) => l.blk),
      ('Most airballs', '💨', (l) => l.airballs),
    ];
    final n = now ?? DateTime.now();
    final out = <GameRecord>[];
    for (final (label, emoji, get) in defs) {
      GameRecord? best;
      for (final entry in _allLogs.entries) {
        final p = store.player(entry.key);
        if (p == null) continue;
        for (final l in entry.value) {
          if (!range.includes(l.when, n)) continue;
          final v = get(l.line);
          if (v > 0 && (best == null || v > best.value)) best = GameRecord(label, emoji, v, p, l);
        }
      }
      if (best != null) out.add(best);
    }
    return out;
  }

  /// Per-player totals for one game day (all its finished games).
  Map<String, StatLine> dayTotals(String dayId) {
    final out = <String, StatLine>{};
    for (final g in store.gamesFor(dayId).where((g) => g.isFinished)) {
      final box = boxScore(g);
      for (final team in box.players) {
        for (final e in team.entries) {
          (out[e.key] ??= StatLine()).merge(e.value);
        }
      }
    }
    return out;
  }

  /// Highest combined game score of the day.
  String? dayMvp(String dayId) {
    String? best;
    var bestScore = double.negativeInfinity;
    for (final e in dayTotals(dayId).entries) {
      if (e.value.isEmpty) continue;
      // Pickup MVPs come from winning: each win is worth a few points.
      final s = e.value.gameScore + e.value.wins * 4;
      if (s > bestScore) {
        bestScore = s;
        best = e.key;
      }
    }
    return best;
  }
}
