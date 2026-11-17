import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../logic/play_text.dart';
import '../../logic/scoring.dart';
import '../../logic/stats.dart';
import '../../models/game.dart';
import '../../models/game_event.dart';
import '../../models/player.dart';
import '../../services/announcer.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_summary_screen.dart';

/// What the scorer tapped in the action pad.
enum _Act {
  ftMade(EventType.ftMade),
  insideMade(EventType.insideMade),
  outsideMade(EventType.outsideMade),
  ftMiss(EventType.ftMiss),
  insideMiss(EventType.insideMiss),
  outsideMiss(EventType.outsideMiss),
  rebound(EventType.rebound),
  assist(EventType.assist),
  steal(EventType.steal),
  block(EventType.block),
  turnover(EventType.turnover),
  foul(EventType.foul),
  airball(null);

  const _Act(this.type);
  final EventType? type;
}

/// Always uses the dark "arena" theme. The Theme sits above the stateful
/// view so its sheets and dialogs inherit it too.
class LiveGameScreen extends StatelessWidget {
  const LiveGameScreen({super.key, required this.gameId, this.justStarted = false});
  final String gameId;
  final bool justStarted;

  @override
  Widget build(BuildContext context) => Theme(
    data: arenaTheme,
    child: _LiveGameView(gameId: gameId, justStarted: justStarted),
  );
}

class _LiveGameView extends StatefulWidget {
  const _LiveGameView({required this.gameId, required this.justStarted});
  final String gameId;
  final bool justStarted;

  @override
  State<_LiveGameView> createState() => _LiveGameScreenState();
}

class _LiveGameScreenState extends State<_LiveGameView> {
  Timer? _ticker;
  String? _promptedAt;
  final _gamePointCalled = <int>{};
  int _lastBeep = -1;
  bool _ending = false;

  AppStore get _store => context.read<AppStore>();
  // Grabbed once: delayed sounds may fire after this screen is gone.
  late final SoundService _sound;
  late final Announcer _announcer;
  Game? get _game => _store.game(widget.gameId);

  @override
  void initState() {
    super.initState();
    _sound = context.read<SoundService>();
    _announcer = context.read<Announcer>();
    if (_store.settings.keepScreenOn) WakelockPlus.enable().catchError((_) {});
    _sound.preload(const [Sfx.score1, Sfx.score2, Sfx.score3, Sfx.brick, Sfx.whistle, Sfx.airball, Sfx.buzzer]);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    if (widget.justStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final g = _game;
        if (g == null) return;
        if (_store.settings.sfx) _sound.play(Sfx.tipoff);
        if (_store.settings.announcer) {
          Future.delayed(const Duration(milliseconds: 1600), () => _sound.announce(_announcer.tipOff(g)));
        }
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WakelockPlus.disable().catchError((_) {});
    super.dispose();
  }

  int _lastWholeSecond = -1;

  void _tick() {
    final g = _game;
    if (g == null || !mounted) return;
    final now = DateTime.now();
    if (g.clockRunning) {
      final left = g.clockRemainingAt(now);
      final secs = (left / 1000).ceil();
      if (secs <= 5 && secs > 0 && secs != _lastBeep && _store.settings.sfx) {
        _lastBeep = secs;
        _sound.play(Sfx.beep);
      }
      if (left <= 0) {
        g.clockRemainingMs = 0;
        g.clockStartedAt = null;
        _store.saveGame(g);
        if (_store.settings.sfx) _sound.play(Sfx.buzzer);
        _askEnd(reason: "Time's up!");
      }
      setState(() {});
    } else if (now.second != _lastWholeSecond) {
      _lastWholeSecond = now.second;
      setState(() {}); // refresh the elapsed timer
    }
  }

  void _toggleClock() {
    final g = _game!;
    final now = DateTime.now();
    if (g.clockRunning) {
      g.clockRemainingMs = g.clockRemainingAt(now);
      g.clockStartedAt = null;
    } else {
      if (g.clockRemainingAt(now) <= 0) return;
      g.clockStartedAt = now;
      _lastBeep = -1;
    }
    HapticFeedback.selectionClick();
    _store.saveGame(g);
  }

  // --------------------------------------------------------------- recording

  GameEvent _record(int team, Player? p, EventType type, {bool airball = false, String? linkedId}) {
    final g = _game!;
    final now = DateTime.now();
    final e = GameEvent(
      id: newId(),
      gameId: g.id,
      team: team,
      playerId: p?.id,
      type: type,
      points: g.rules.pointsFor(type),
      airball: airball,
      linkedId: linkedId,
      at: now,
      clockMs: g.hasClock ? g.clockRemainingAt(now) : null,
    );
    _store.addEvent(e);
    if (e.points > 0) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    return e;
  }

  void _feedback(GameEvent e, Player? p) {
    final settings = _store.settings;
    if (settings.sfx) {
      final sfx = _announcer.sfxFor(e);
      if (sfx != null) _sound.play(sfx);
    }
    if (settings.announcer) {
      final call = _announcer.callFor(e, p, _game!.rules);
      if (call != null) {
        // Let the effect land first (the airball's sad trombone gets its moment).
        Future.delayed(Duration(milliseconds: e.airball ? 1900 : 450), () => _sound.announce(call));
      }
    }
  }

  Future<void> _afterScore() async {
    final g = _game;
    if (g == null || !mounted) return;
    final scores = teamScores(_store.eventsFor(g.id));
    final target = g.rules.targetScore;
    if (target == null) return;
    if (targetReached(g.rules, scores)) {
      final key = '${scores[0]}-${scores[1]}';
      if (_promptedAt == key) return;
      _promptedAt = key;
      final w = scores[0] > scores[1] ? 0 : 1;
      await _askEnd(reason: '${g.teams[w].name} reached $target!');
      return;
    }
    for (var t = 0; t < 2; t++) {
      final mine = scores[t], theirs = scores[1 - t];
      final canWin =
          mine + g.rules.scoring.insidePoints >= target &&
          (!g.rules.winByTwo || mine + g.rules.scoring.insidePoints - theirs >= 2);
      if (canWin && !_gamePointCalled.contains(t)) {
        _gamePointCalled.add(t);
        if (_store.settings.announcer) {
          Future.delayed(const Duration(milliseconds: 2200), () => _sound.announce(_announcer.gamePoint(g.teams[t])));
        }
      }
    }
  }

  Future<void> _onPlayerTap(int team, Player p) async {
    final g = _game!;
    final box = context.read<StatsEngine>().boxScore(g);
    final act = await showModalBottomSheet<_Act>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActionSheet(player: p, team: g.teams[team], line: box.lineFor(p.id), scoring: g.rules.scoring),
    );
    if (act == null || !mounted) return;
    await _apply(act, team, p);
  }

  Future<void> _onTeamTap(int team) async {
    final g = _game!;
    final act = await showModalBottomSheet<_Act>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ActionSheet(player: null, team: g.teams[team], line: null, scoring: g.rules.scoring),
    );
    if (act == null || !mounted) return;
    await _apply(act, team, null);
  }

  Future<void> _apply(_Act act, int team, Player? p) async {
    final g = _game!;
    final settings = _store.settings;
    if (act == _Act.airball) {
      final type = await showModalBottomSheet<EventType>(
        context: context,
        builder: (ctx) => _ChoiceSheet<EventType>(
          title: 'Airball from where? 💨',
          options: [
            (EventType.insideMiss, g.rules.scoring.insideLabel),
            (EventType.outsideMiss, g.rules.scoring.outsideLabel),
          ],
        ),
      );
      if (type == null || !mounted) return;
      final e = _record(team, p, type, airball: true);
      _feedback(e, p);
      if (settings.askRebound) await _askRebound(e);
      return;
    }
    final type = act.type!;
    final e = _record(team, p, type);
    _feedback(e, p);
    if (type == EventType.insideMade || type == EventType.outsideMade) {
      final mates = g.teams[team].playerIds.where((id) => id != p?.id).map(_store.player).whereType<Player>().toList();
      if (settings.askAssist && p != null && mates.isNotEmpty) {
        final a = await _pickPlayer('Assisted by?', [(g.teams[team], mates)], skip: 'No assist');
        if (a != null && mounted) _record(team, a, EventType.assist, linkedId: e.id);
      }
    } else if (type.isMiss && settings.askRebound) {
      await _askRebound(e);
    }
    if (e.points > 0) await _afterScore();
  }

  Future<void> _askRebound(GameEvent shot) async {
    final g = _game!;
    final groups = [
      for (final t in [shot.team, 1 - shot.team])
        (g.teams[t], g.teams[t].playerIds.map(_store.player).whereType<Player>().toList()),
    ];
    if (groups.every((gr) => gr.$2.isEmpty)) return;
    final r = await _pickPlayer('Rebound?', groups, skip: 'Skip');
    if (r == null || !mounted) return;
    _record(g.teamIndexOf(r.id) ?? shot.team, r, EventType.rebound, linkedId: shot.id);
  }

  Future<Player?> _pickPlayer(String title, List<(TeamSide, List<Player>)> groups, {required String skip}) {
    return showModalBottomSheet<Player>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickPlayerSheet(title: title, groups: groups, skipLabel: skip),
    );
  }

  void _undo() {
    final g = _game;
    if (g == null) return;
    final e = _store.undoLast(g.id);
    if (e == null) return;
    HapticFeedback.heavyImpact();
    toast(context, 'Undone: ${playText(e, g, _store.player(e.playerId))}');
  }

  Future<void> _askEnd({String? reason}) async {
    final g = _game;
    if (g == null || _ending || !mounted) return;
    _ending = true;
    final scores = teamScores(_store.eventsFor(g.id));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(reason ?? 'End the game?'),
        content: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TeamSwatch(color: g.teams[0].color, size: 18),
            const SizedBox(width: 8),
            Text('${scores[0]}', style: scoreStyle(40)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('–', style: TextStyle(fontSize: 28)),
            ),
            Text('${scores[1]}', style: scoreStyle(40)),
            const SizedBox(width: 8),
            TeamSwatch(color: g.teams[1].color, size: 18),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep playing')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.flag_rounded),
            label: const Text('End game'),
          ),
        ],
      ),
    );
    _ending = false;
    if (ok != true || !mounted) return;
    _store.finishGame(g);
    final settings = _store.settings;
    if (settings.sfx) {
      _sound.play(Sfx.buzzer);
      Future.delayed(const Duration(milliseconds: 900), () => _sound.play(Sfx.crowd));
    }
    if (settings.announcer) {
      Future.delayed(const Duration(milliseconds: 1500), () => _sound.announce(_announcer.gameOver(g, scores)));
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => GameSummaryScreen(gameId: g.id, celebrate: true)),
    );
  }

  Future<void> _menu(String v) async {
    final g = _game!;
    final s = _store.settings;
    switch (v) {
      case 'sfx':
        s.sfx = !s.sfx;
        _store.saveSettings();
      case 'announcer':
        s.announcer = !s.announcer;
        _store.saveSettings();
      case 'assist':
        s.askAssist = !s.askAssist;
        _store.saveSettings();
      case 'rebound':
        s.askRebound = !s.askRebound;
        _store.saveSettings();
      case 'roster':
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _RosterSheet(gameId: g.id),
        );
      case 'clock':
        g.clockStartedAt = null;
        g.clockRemainingMs = (g.rules.minutes ?? 0) * 60000;
        _store.saveGame(g);
      case 'delete':
        final ok = await confirm(
          context,
          title: 'Delete this game?',
          message: 'The score and every stat recorded in it will be removed.',
          confirmLabel: 'Delete',
          destructive: true,
        );
        if (ok && mounted) {
          Navigator.pop(context);
          _store.deleteGame(g.id);
        }
    }
  }

  void _showPlays() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlaysSheet(gameId: widget.gameId),
    );
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final g = store.game(widget.gameId);
    if (g == null) return const Scaffold(body: SizedBox.shrink());
    final box = context.read<StatsEngine>().boxScore(g);
    final events = store.eventsFor(g.id);
    final fouls = teamFouls(events);
    final s = store.settings;
    final last = events.isEmpty
        ? null
        : (events.last.linkedId != null
              ? events.firstWhere((e) => e.id == events.last.linkedId, orElse: () => events.last)
              : events.last);
    final lastAssist = last == null
        ? null
        : events.where((e) => e.linkedId == last.id && e.type == EventType.assist).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.courtLow,
      appBar: AppBar(
        backgroundColor: AppColors.courtLow,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(g.title.toUpperCase()),
                const SizedBox(width: 10),
                if (g.isLive) const LivePill() else const Pill('FINAL', color: Colors.white54),
              ],
            ),
            Text(
              g.rules.summary,
              style: const TextStyle(fontSize: 12.5, color: Colors.white60, fontFamily: bodyFont),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.sfx ? 'Mute sounds' : 'Unmute sounds',
            icon: Icon(s.sfx ? Icons.volume_up_rounded : Icons.volume_off_rounded),
            onPressed: () => _menu('sfx'),
          ),
          PopupMenuButton<String>(
            onSelected: _menu,
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'announcer', checked: s.announcer, child: const Text('Announcer voice')),
              CheckedPopupMenuItem(value: 'assist', checked: s.askAssist, child: const Text('Ask for assists')),
              CheckedPopupMenuItem(value: 'rebound', checked: s.askRebound, child: const Text('Ask for rebounds')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'roster', child: Text('Edit teams / subs')),
              if (g.hasClock) const PopupMenuItem(value: 'clock', child: Text('Reset clock')),
              const PopupMenuItem(value: 'delete', child: Text('Delete game')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          _Scoreboard(game: g, scores: box.scores, fouls: fouls, onClockTap: g.hasClock ? _toggleClock : null),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var t = 0; t < 2; t++) ...[
                    if (t == 1) const SizedBox(width: 8),
                    Expanded(child: _teamColumn(g, t, box)),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        text: last == null
            ? 'Tap a player to log a play'
            : playText(last, g, store.player(last.playerId), assist: store.player(lastAssist?.playerId)),
        hasLast: last != null,
        onUndo: _undo,
        onPlays: _showPlays,
        onEnd: () => _askEnd(),
      ),
    );
  }

  Widget _teamColumn(Game g, int t, BoxScore box) {
    final team = g.teams[t];
    final players = team.playerIds.map(_store.player).whereType<Player>().toList();
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      children: [
        for (final p in players)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PlayerTile(player: p, team: team, line: box.lineFor(p.id), onTap: () => _onPlayerTap(t, p)),
          ),
        _TeamTile(team: team, onTap: () => _onTeamTap(t), compact: players.isNotEmpty),
      ],
    );
  }
}

// ======================================================================
// Scoreboard

class _Scoreboard extends StatelessWidget {
  const _Scoreboard({required this.game, required this.scores, required this.fouls, this.onClockTap});
  final Game game;
  final List<int> scores;
  final List<int> fouls;
  final VoidCallback? onClockTap;

  @override
  Widget build(BuildContext context) {
    final lead = leaderIndex(scores);
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 2, 10, 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF232838), Color(0xFF181B27)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _TeamScore(team: game.teams[0], score: scores[0], fouls: fouls[0], leading: lead == 0),
          ),
          _Center(game: game, onClockTap: onClockTap),
          Expanded(
            child: _TeamScore(team: game.teams[1], score: scores[1], fouls: fouls[1], leading: lead == 1),
          ),
        ],
      ),
    );
  }
}

class _TeamScore extends StatelessWidget {
  const _TeamScore({required this.team, required this.score, required this.fouls, required this.leading});
  final TeamSide team;
  final int score;
  final int fouls;
  final bool leading;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: visibleTeamColor(team.color, onDark: true),
            borderRadius: BorderRadius.circular(3),
            boxShadow: leading ? [BoxShadow(color: team.color.withValues(alpha: 0.6), blurRadius: 10)] : null,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          team.name.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: displayFont,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: 1.2,
            color: Colors.white70,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          transitionBuilder: (child, anim) => ScaleTransition(
            scale: Tween(begin: 1.35, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
            child: FadeTransition(opacity: anim, child: child),
          ),
          child: Text(
            '$score',
            key: ValueKey(score),
            style: scoreStyle(80, color: leading ? Colors.white : Colors.white.withValues(alpha: 0.82)),
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'FOULS ',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white38, letterSpacing: 0.8),
            ),
            Text(
              '$fouls',
              style: scoreStyle(
                15,
                color: fouls >= 7 ? AppColors.loss : (fouls >= 5 ? AppColors.foul : Colors.white60),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Center extends StatelessWidget {
  const _Center({required this.game, this.onClockTap});
  final Game game;
  final VoidCallback? onClockTap;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final target = game.rules.targetScore;
    final children = <Widget>[];
    if (game.hasClock) {
      final left = game.clockRemainingAt(now);
      final running = game.clockRunning;
      children.add(
        GestureDetector(
          onTap: onClockTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: running ? AppColors.orange.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: running ? AppColors.orange : Colors.white24),
            ),
            child: Column(
              children: [
                Text(
                  formatClock(left),
                  style: scoreStyle(28, color: left < 60000 ? const Color(0xFFFF6B6B) : Colors.white),
                ),
                Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 18, color: Colors.white70),
              ],
            ),
          ),
        ),
      );
    } else if (game.startedAt != null) {
      final el = (game.endedAt ?? now).difference(game.startedAt!);
      children.add(
        Text(
          '${el.inMinutes}:${(el.inSeconds % 60).toString().padLeft(2, '0')}',
          style: scoreStyle(20, color: Colors.white54, weight: FontWeight.w700),
        ),
      );
    }
    if (target != null) {
      children.add(const SizedBox(height: 6));
      children.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'TO $target',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 12,
              color: Colors.white70,
              letterSpacing: 0.8,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      width: 82,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

// ======================================================================
// Player tiles

class _PlayerTile extends StatelessWidget {
  const _PlayerTile({required this.player, required this.team, required this.line, required this.onTap});
  final Player player;
  final TeamSide team;
  final StatLine? line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = line;
    final pf = l?.pf ?? 0;
    return Material(
      color: AppColors.courtCard,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: visibleTeamColor(team.color, onDark: true), width: 4)),
          ),
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  PlayerAvatar(player: player, size: 38),
                  if (player.jerseyNumber != null)
                    Positioned(
                      right: -6,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: team.color,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: AppColors.courtCard, width: 1.5),
                        ),
                        child: Text(
                          '${player.jerseyNumber}',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: team.onColor),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      player.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${l?.pts ?? 0}',
                            style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w900),
                          ),
                          const TextSpan(text: 'p  '),
                          TextSpan(
                            text: '${l?.reb ?? 0}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: 'r  '),
                          TextSpan(
                            text: '${l?.ast ?? 0}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          const TextSpan(text: 'a'),
                        ],
                      ),
                      style: const TextStyle(fontSize: 13, color: Colors.white54, fontFamily: displayFont),
                    ),
                  ],
                ),
              ),
              if (pf > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: (pf >= 5 ? AppColors.loss : AppColors.foul).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'F$pf',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: pf >= 5 ? AppColors.loss : AppColors.foul,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TeamTile extends StatelessWidget {
  const _TeamTile({required this.team, required this.onTap, required this.compact});
  final TeamSide team;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: compact ? 44 : 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline_rounded, size: 18, color: Colors.white60),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  compact ? 'Team play' : '${team.name} score',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.text,
    required this.hasLast,
    required this.onUndo,
    required this.onPlays,
    required this.onEnd,
  });
  final String text;
  final bool hasLast;
  final VoidCallback onUndo;
  final VoidCallback onPlays;
  final VoidCallback onEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.court,
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: hasLast ? onPlays : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'LAST PLAY',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                                color: Colors.white38,
                                letterSpacing: 1,
                              ),
                            ),
                            if (hasLast) const Icon(Icons.expand_less_rounded, size: 16, color: Colors.white38),
                          ],
                        ),
                        Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Undo last play',
                onPressed: hasLast ? onUndo : null,
                icon: const Icon(Icons.undo_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: onEnd,
                icon: const Icon(Icons.flag_rounded, size: 20),
                label: const Text('End'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ======================================================================
// Sheets

class _ActionSheet extends StatelessWidget {
  const _ActionSheet({required this.player, required this.team, required this.line, required this.scoring});
  final Player? player;
  final TeamSide team;
  final StatLine? line;
  final ScoringMode scoring;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final l = line;
    Widget btn(_Act a, String top, String bottom, Color color, {bool filled = false}) => Expanded(
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Material(
          color: filled ? color : color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.pop(context, a),
            child: SizedBox(
              height: 66,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(top, style: scoreStyle(24, color: filled ? Colors.white : color)),
                  const SizedBox(height: 2),
                  Text(
                    bottom,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: filled ? Colors.white.withValues(alpha: 0.9) : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    const grey = Color(0xFF94A3B8);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Row(
                children: [
                  if (p != null)
                    PlayerAvatar(player: p, size: 44, ring: team.color)
                  else
                    TeamSwatch(color: team.color, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p?.displayName ?? '${team.name} (team)', style: Theme.of(context).textTheme.titleLarge),
                        Text(
                          l == null
                              ? 'Not credited to a player'
                              : '${l.pts} PTS · ${l.reb} REB · ${l.ast} AST · ${l.pf} PF',
                          style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                btn(_Act.ftMade, '+1', 'FREE THROW', AppColors.made, filled: true),
                btn(_Act.insideMade, '+${scoring.insidePoints}', scoring.insideLabel, AppColors.made, filled: true),
                btn(_Act.outsideMade, '+${scoring.outsidePoints}', scoring.outsideLabel, AppColors.made, filled: true),
              ],
            ),
            Row(
              children: [
                btn(_Act.ftMiss, 'MISS', 'FREE THROW', grey),
                btn(_Act.insideMiss, 'MISS', scoring.insideLabel, grey),
                btn(_Act.outsideMiss, 'MISS', scoring.outsideLabel, grey),
              ],
            ),
            if (p != null)
              Row(
                children: [
                  btn(_Act.rebound, 'REB', 'REBOUND', const Color(0xFF60A5FA)),
                  btn(_Act.assist, 'AST', 'ASSIST', const Color(0xFF60A5FA)),
                  btn(_Act.steal, 'STL', 'STEAL', const Color(0xFFA78BFA)),
                  btn(_Act.block, 'BLK', 'BLOCK', const Color(0xFFA78BFA)),
                ],
              ),
            Row(
              children: [
                btn(_Act.turnover, 'TO', 'TURNOVER', const Color(0xFFF87171)),
                btn(_Act.foul, 'FOUL', 'PERSONAL', AppColors.foul),
                if (p != null) btn(_Act.airball, '💨', 'AIRBALL', const Color(0xFFF472B6)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PickPlayerSheet extends StatelessWidget {
  const _PickPlayerSheet({required this.title, required this.groups, required this.skipLabel});
  final String title;
  final List<(TeamSide, List<Player>)> groups;
  final String skipLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            for (final (team, players) in groups)
              if (players.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    TeamSwatch(color: team.color, size: 12),
                    const SizedBox(width: 6),
                    Text(
                      team.name.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Colors.white60,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in players)
                      InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () => Navigator.pop(context, p),
                        child: Container(
                          width: 84,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(
                            color: AppColors.courtCard,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: team.color.withValues(alpha: 0.5)),
                          ),
                          child: Column(
                            children: [
                              PlayerAvatar(player: p, size: 40),
                              const SizedBox(height: 6),
                              Text(
                                p.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => Navigator.pop(context), child: Text(skipLabel)),
          ],
        ),
      ),
    );
  }
}

class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({required this.title, required this.options});
  final String title;
  final List<(T, String)> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Row(
              children: [
                for (final (v, label) in options)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: FilledButton(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 64)),
                        onPressed: () => Navigator.pop(context, v),
                        child: Text(label, style: scoreStyle(24, color: Colors.white)),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Full play-by-play with delete, for fixing mistakes beyond the last play.
class _PlaysSheet extends StatelessWidget {
  const _PlaysSheet({required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final g = store.game(gameId);
    if (g == null) return const SizedBox.shrink();
    final events = store.eventsFor(gameId);
    final running = runningScores(events);
    final idx = List.generate(events.length, (i) => i).reversed.toList();
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Play-by-play',
              style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 24),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: idx.length,
              itemBuilder: (context, k) {
                final i = idx[k];
                final e = events[i];
                return ListTile(
                  dense: true,
                  leading: Container(
                    width: 6,
                    height: 32,
                    decoration: BoxDecoration(
                      color: visibleTeamColor(g.teams[e.team].color, onDark: true),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  title: Text(
                    playText(e, g, store.player(e.playerId)),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  subtitle: Text(formatTime(e.at)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${running[i][0]}-${running[i][1]}', style: scoreStyle(18, weight: FontWeight.w700)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 20),
                        onPressed: () => store.removeEvent(e),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Move players between teams or sub people in mid-game.
class _RosterSheet extends StatelessWidget {
  const _RosterSheet({required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final g = store.game(gameId);
    if (g == null) return const SizedBox.shrink();
    final day = store.gameDay(g.gameDayId);
    final ids = {...?day?.attendeeIds, ...g.allPlayerIds};
    final players = ids.map(store.player).whereType<Player>().toList()..sort((a, b) => a.name.compareTo(b.name));
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Text(
              'Teams & subs',
              style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 24),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Stats already recorded stay with each player.', style: TextStyle(color: Colors.white60)),
          ),
          Expanded(
            child: ListView(
              children: [
                for (final p in players)
                  ListTile(
                    leading: PlayerAvatar(player: p, size: 36),
                    title: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                    trailing: SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: [
                        const ButtonSegment(value: -1, label: Text('Bench')),
                        for (var t = 0; t < 2; t++)
                          ButtonSegment(
                            value: t,
                            label: Text(g.teams[t].name, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      selected: {g.teamIndexOf(p.id) ?? -1},
                      onSelectionChanged: (s) {
                        for (final t in g.teams) {
                          t.playerIds.remove(p.id);
                        }
                        if (s.first >= 0) g.teams[s.first].playerIds.add(p.id);
                        store.saveGame(g);
                      },
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
