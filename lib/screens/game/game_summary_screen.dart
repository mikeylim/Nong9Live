import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../logic/play_text.dart';
import '../../logic/stats.dart';
import '../../logic/youtube.dart';
import '../../models/game.dart';
import '../../models/game_event.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/game_widgets.dart';
import '../players/player_detail_screen.dart';
import '../video/video_screen.dart';
import 'live_game_screen.dart';
import 'team_builder_screen.dart';

class GameSummaryScreen extends StatefulWidget {
  const GameSummaryScreen({super.key, required this.gameId, this.celebrate = false});
  final String gameId;
  final bool celebrate;

  @override
  State<GameSummaryScreen> createState() => _GameSummaryScreenState();
}

class _GameSummaryScreenState extends State<GameSummaryScreen> {
  final _confetti = ConfettiController(duration: const Duration(seconds: 2));
  bool _allPlays = false;

  @override
  void initState() {
    super.initState();
    if (widget.celebrate) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _openPlayer(Player p) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: p.id)));

  void _share(AppStore store, BoxScore box) {
    final g = box.game;
    final day = store.gameDay(g.gameDayId);
    final b = StringBuffer('🏀 ${store.settings.crewName} · ${g.title}');
    if (day != null) b.write(' · ${formatDay(day.date)}');
    b.writeln();
    for (var t = 0; t < 2; t++) {
      b.writeln('${box.winner == t ? '🏆 ' : ''}${g.teams[t].name}: ${box.scores[t]}');
    }
    final mvp = store.player(box.mvpId);
    if (mvp != null) {
      final l = box.lineFor(mvp.id)!;
      b.writeln('⭐ MVP ${mvp.displayName}: ${l.pts} pts, ${l.reb} reb, ${l.ast} ast');
    }
    for (var t = 0; t < 2; t++) {
      final lines = box.players[t].entries.toList()..sort((a, c) => c.value.pts.compareTo(a.value.pts));
      b.writeln('\n${g.teams[t].name}');
      for (final e in lines) {
        final p = store.player(e.key);
        b.writeln('  ${p?.displayName ?? '?'} ${e.value.pts}p ${e.value.reb}r ${e.value.ast}a');
      }
    }
    SharePlus.instance.share(ShareParams(text: b.toString().trim()));
  }

  void _nextGame(BoxScore box) {
    final g = box.game;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        void go(List<TeamSide>? teams, {bool lock = false}) {
          Navigator.pop(ctx);
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => TeamBuilderScreen(dayId: g.gameDayId, initialTeams: teams, lockFirstTeam: lock),
            ),
          );
        }

        final w = box.winner;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Next game', style: Theme.of(ctx).textTheme.headlineSmall),
                const SizedBox(height: 12),
                if (w != null)
                  _OptionTile(
                    emoji: '👑',
                    title: 'Winner stays',
                    subtitle: '${g.teams[w].name} stays on, challengers come off the bench',
                    onTap: () => go([
                      g.teams[w].copy(),
                      TeamSide(name: g.teams[1 - w].name, colorValue: g.teams[1 - w].colorValue),
                    ], lock: true),
                  ),
                _OptionTile(
                  emoji: '🔁',
                  title: 'Run it back',
                  subtitle: 'Same teams, rematch',
                  onTap: () => go(g.teams.map((t) => t.copy()).toList()),
                ),
                _OptionTile(
                  emoji: '🎲',
                  title: 'New teams',
                  subtitle: 'Pick or shuffle fresh teams',
                  onTap: () => go(null),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final g = store.game(widget.gameId);
    if (g == null) return const Scaffold(body: SizedBox.shrink());
    final stats = context.read<StatsEngine>();
    final box = stats.boxScore(g);
    final day = store.gameDay(g.gameDayId);
    final mvp = store.player(box.mvpId);
    final events = store.eventsFor(g.id);
    final hasVideo = day?.videos.isNotEmpty == true;
    final syncedForGame = g.startedAt == null ? null : day?.videoFor(g.startedAt!);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(g.title),
            actions: [
              IconButton(tooltip: 'Share', icon: const Icon(Icons.ios_share_rounded), onPressed: () => _share(store, box)),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'reopen') {
                    store.reopenGame(g);
                    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LiveGameScreen(gameId: g.id)));
                  } else if (v == 'mvp') {
                    _pickMvp(store, g);
                  } else if (v == 'delete') {
                    final ok = await confirm(
                      context,
                      title: 'Delete this game?',
                      message: 'The score and every stat recorded in it will be removed.',
                      confirmLabel: 'Delete',
                      destructive: true,
                    );
                    if (ok && context.mounted) {
                      Navigator.pop(context);
                      store.deleteGame(g.id);
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'reopen', child: Text(g.isLive ? 'Back to scoring' : 'Reopen & fix stats')),
                  const PopupMenuItem(value: 'mvp', child: Text('Choose MVP')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete game')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
            children: [
              _FinalBoard(box: box, dayLabel: day == null ? null : formatDay(day.date)),
              if (mvp != null) ...[
                const SizedBox(height: 12),
                _MvpCard(player: mvp, line: box.lineFor(mvp.id)!, onTap: () => _openPlayer(mvp)),
              ],
              if (hasVideo) ...[
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.smart_display_rounded, color: Color(0xFFFF0033)),
                  label: Text(syncedForGame != null
                      ? 'Watch this game (${formatVideoTime(syncedForGame.secondsAt(g.startedAt!)!)})'
                      : 'Watch the video'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoScreen(
                        dayId: g.gameDayId,
                        videoLinkId: (syncedForGame ?? day!.videos.first).id,
                        startAt: g.startedAt,
                        focusGameId: g.id,
                      ),
                    ),
                  ),
                ),
              ],
              const SectionHeader('Box score', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
              for (var t = 0; t < 2; t++) ...[
                BoxScoreTable(box: box, team: t, store: store, onPlayerTap: _openPlayer),
                const SizedBox(height: 12),
              ],
              SectionHeader(
                'Play-by-play',
                padding: const EdgeInsets.fromLTRB(4, 16, 0, 6),
                trailing: TextButton(
                  onPressed: () => setState(() => _allPlays = !_allPlays),
                  child: Text(_allPlays ? 'Scoring only' : 'All plays'),
                ),
              ),
              _PlayList(game: g, events: events, all: _allPlays),
            ],
          ),
          bottomNavigationBar: g.isFinished
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton.icon(
                      icon: const Icon(Icons.sports_basketball_rounded),
                      label: const Text('Next game'),
                      onPressed: () => _nextGame(box),
                    ),
                  ),
                )
              : null,
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            blastDirection: pi / 2,
            numberOfParticles: 30,
            emissionFrequency: 0.06,
            gravity: 0.25,
            colors: [
              AppColors.orange,
              AppColors.gold,
              Colors.white,
              if (box.winner != null) g.teams[box.winner!].color,
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickMvp(AppStore store, Game g) async {
    final ids = g.allPlayerIds.toList();
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Choose MVP', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18))),
            ListTile(
              leading: const Icon(Icons.auto_awesome_rounded),
              title: const Text('Automatic (best game score on the winning team)'),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final id in ids)
              if (store.player(id) != null)
                ListTile(
                  leading: PlayerAvatar(player: store.player(id), size: 34),
                  title: Text(store.player(id)!.displayName),
                  onTap: () => Navigator.pop(ctx, id),
                ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    g.mvpOverrideId = picked.isEmpty ? null : picked;
    store.saveGame(g);
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.emoji, required this.title, required this.subtitle, required this.onTap});
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Text(emoji, style: const TextStyle(fontSize: 28)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        ),
      ),
    );
  }
}

class _FinalBoard extends StatelessWidget {
  const _FinalBoard({required this.box, this.dayLabel});
  final BoxScore box;
  final String? dayLabel;

  @override
  Widget build(BuildContext context) {
    final g = box.game;
    Widget side(int t) {
      final team = g.teams[t];
      final won = box.winner == t;
      return Expanded(
        child: Column(
          children: [
            SizedBox(height: 26, child: won ? const Text('👑', style: TextStyle(fontSize: 22)) : null),
            Container(
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: visibleTeamColor(team.color, onDark: true),
                borderRadius: BorderRadius.circular(3),
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
            Text(
              '${box.scores[t]}',
              style: scoreStyle(72, color: box.winner == null || won ? Colors.white : Colors.white38),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF262B3D), Color(0xFF161925)],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              side(0),
              Column(
                children: [
                  const SizedBox(height: 40),
                  if (g.isLive) const LivePill() else const Pill('FINAL', color: Colors.white70),
                ],
              ),
              side(1),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              ?dayLabel,
              if (g.startedAt != null) formatTime(g.startedAt!),
              if (g.duration != null) formatDuration(g.duration!),
              g.rules.summary,
            ].join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _MvpCard extends StatelessWidget {
  const _MvpCard({required this.player, required this.line, required this.onTap});
  final Player player;
  final StatLine line;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.3), AppColors.gold.withValues(alpha: 0.02)]),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              PlayerAvatar(player: player, size: 56, ring: AppColors.gold),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GAME MVP',
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 1.2, color: AppColors.gold)),
                    Text(player.displayName, style: Theme.of(context).textTheme.headlineSmall),
                    Text(
                      '${line.pts} PTS · ${line.reb} REB · ${line.ast} AST'
                      '${line.stl > 0 ? ' · ${line.stl} STL' : ''}${line.blk > 0 ? ' · ${line.blk} BLK' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Text('⭐', style: TextStyle(fontSize: 30)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayList extends StatelessWidget {
  const _PlayList({required this.game, required this.events, required this.all});
  final Game game;
  final List<GameEvent> events;
  final bool all;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final day = store.gameDay(game.gameDayId);
    final running = runningScores(events);
    final cs = Theme.of(context).colorScheme;
    final rows = <Widget>[];
    for (var i = events.length - 1; i >= 0; i--) {
      final e = events[i];
      final isHighlight = e.points > 0 || e.airball || e.type == EventType.block || e.type == EventType.steal;
      if (e.linkedId != null && e.type == EventType.assist) continue; // shown with the shot
      if (!all && !isHighlight) continue;
      final assist = events.where((x) => x.linkedId == e.id && x.type == EventType.assist).firstOrNull;
      final video = day?.videoFor(e.at);
      final sec = video?.secondsAt(e.at);
      rows.add(
        InkWell(
          onTap: video == null
              ? null
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => VideoScreen(dayId: game.gameDayId, videoLinkId: video.id, startAt: e.at, focusGameId: game.id),
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 30,
                  decoration: BoxDecoration(
                    color: visibleTeamColorIn(context, game.teams[e.team].color),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        playText(e, game, store.player(e.playerId), assist: store.player(assist?.playerId)),
                        style: TextStyle(fontWeight: e.points > 0 ? FontWeight.w700 : FontWeight.w500, fontSize: 14.5),
                      ),
                      Text(
                        [
                          formatTime(e.at),
                          if (e.clockMs != null) '${formatClock(e.clockMs!)} left',
                        ].join(' · '),
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (sec != null) ...[
                  Icon(Icons.play_circle_outline_rounded, size: 20, color: AppColors.orange.withValues(alpha: 0.9)),
                  const SizedBox(width: 4),
                  Text(formatVideoTime(sec), style: const TextStyle(fontSize: 12, color: AppColors.orange, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 10),
                ],
                Text('${running[i][0]}-${running[i][1]}', style: scoreStyle(18, weight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      );
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('No plays recorded.', style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return Card(clipBehavior: Clip.antiAlias, child: Column(children: rows));
  }
}
