import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app.dart';
import '../../data/app_store.dart';
import '../../data/demo_data.dart';
import '../../logic/format.dart';
import '../../logic/stats.dart';
import '../../models/game_day.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/game_widgets.dart';
import '../game/live_game_screen.dart';
import '../players/player_detail_screen.dart';
import '../settings/settings_screen.dart';
import 'game_day_form.dart';
import 'game_day_screen.dart';

class RunsScreen extends StatelessWidget {
  const RunsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final now = DateTime.now();
    final days = store.gameDays;
    final today = store.gameDayOn(now);
    final live = store.liveGame;
    final history = days.where((d) => d.id != today?.id).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(crewName: store.settings.crewName, now: now)),
          if (live != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: _LiveBanner(gameId: live.id),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: today == null
                  ? _StartCard(hasPlayers: store.players.isNotEmpty)
                  : _TodayCard(day: today),
            ),
          ),
          if (store.allGames.any((g) => g.isFinished))
            SliverToBoxAdapter(child: _Highlights(store: store, stats: stats)),
          if (history.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('History')),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.separated(
                itemCount: history.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _GameDayCard(day: history[i]),
              ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.crewName, required this.now});
  final String crewName;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatDayLong(now).toUpperCase(),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        crewName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('🏀', style: TextStyle(fontSize: 28)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
    );
  }
}

class _LiveBanner extends StatelessWidget {
  const _LiveBanner({required this.gameId});
  final String gameId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final game = store.game(gameId);
    if (game == null) return const SizedBox.shrink();
    final box = context.read<StatsEngine>().boxScore(game);
    return Material(
      color: AppColors.courtCard,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LiveGameScreen(gameId: gameId))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LivePill(),
                  const SizedBox(height: 6),
                  Text(game.title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TeamSwatch(color: game.teams[0].color),
                    const SizedBox(width: 8),
                    Text('${box.scores[0]}', style: scoreStyle(34, color: Colors.white)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('–', style: TextStyle(color: Colors.white54, fontSize: 24)),
                    ),
                    Text('${box.scores[1]}', style: scoreStyle(34, color: Colors.white)),
                    const SizedBox(width: 8),
                    TeamSwatch(color: game.teams[1].color),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded, color: AppColors.orange, size: 36),
            ],
          ),
        ),
      ),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.hasPlayers});
  final bool hasPlayers;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A3D), AppColors.orangeDeep],
        ),
        boxShadow: [BoxShadow(color: AppColors.orange.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Positioned(right: -6, top: -10, child: Text('🏀', style: TextStyle(fontSize: 64))),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasPlayers ? 'READY TO RUN?' : 'WELCOME!',
                style: const TextStyle(
                  fontFamily: displayFont,
                  fontWeight: FontWeight.w900,
                  fontSize: 32,
                  color: Colors.white,
                  height: 1,
                ),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: Text(
                  hasPlayers
                      ? 'Check who showed up, pick teams and keep score live.'
                      : 'Add your crew first. Everyone gets a player card with stats.',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.orangeDeep),
                      icon: Icon(hasPlayers ? Icons.play_arrow_rounded : Icons.person_add_alt_1_rounded),
                      label: Text(hasPlayers ? "Start today's run" : 'Add players'),
                      onPressed: () {
                        if (hasPlayers) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const GameDayFormScreen()));
                        } else {
                          context.read<ShellController>().value = ShellController.players;
                        }
                      },
                    ),
                  ),
                ],
              ),
              if (!hasPlayers)
                Center(
                  child: TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: () async {
                      final ok = await confirm(
                        context,
                        title: 'Load demo data?',
                        message: 'Adds 12 sample players and 5 weeks of simulated games so you can explore. '
                            'You can erase it later in Settings.',
                        confirmLabel: 'Load demo',
                      );
                      if (ok && context.mounted) DemoData.seed(context.read<AppStore>());
                    },
                    child: const Text('or try it with demo data'),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({required this.day});
  final GameDay day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final games = store.gamesFor(day.id);
    final attendees = day.attendeeIds.map(store.player).whereType<Player>().toList();
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameDayScreen(dayId: day.id))),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Pill("TODAY'S RUN", color: AppColors.orange),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 10),
              if (day.location != null)
                Text(day.location!, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(child: AvatarStack(players: attendees, size: 28, max: 8)),
                  Text('${attendees.length} players', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ],
              ),
              if (games.isNotEmpty) ...[
                const SizedBox(height: 12),
                for (final g in games) _MiniScore(box: stats.boxScore(g)),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                icon: const Icon(Icons.add_rounded),
                label: Text(games.isEmpty ? 'Start game 1' : 'New game'),
                onPressed: () => openNewGame(context, day),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniScore extends StatelessWidget {
  const _MiniScore({required this.box});
  final BoxScore box;

  @override
  Widget build(BuildContext context) {
    final g = box.game;
    final cs = Theme.of(context).colorScheme;
    TextStyle s(int t) => scoreStyle(
          20,
          weight: box.winner == t ? FontWeight.w900 : FontWeight.w700,
          color: box.winner != null && box.winner != t ? cs.onSurfaceVariant : cs.onSurface,
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(g.title, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
          TeamSwatch(color: g.teams[0].color, size: 12),
          const SizedBox(width: 6),
          Text('${box.scores[0]}', style: s(0)),
          Text('  –  ', style: TextStyle(color: cs.onSurfaceVariant)),
          Text('${box.scores[1]}', style: s(1)),
          const SizedBox(width: 6),
          TeamSwatch(color: g.teams[1].color, size: 12),
          const Spacer(),
          if (g.isLive) const LivePill(),
        ],
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.store, required this.stats});
  final AppStore store;
  final StatsEngine stats;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[];
    final lastDay = store.gameDays.where((d) => store.gamesFor(d.id).any((g) => g.isFinished)).firstOrNull;
    if (lastDay != null) {
      final mvp = store.player(stats.dayMvp(lastDay.id));
      final line = mvp == null ? null : stats.dayTotals(lastDay.id)[mvp.id];
      if (mvp != null && line != null) {
        cards.add(_HighlightCard(
          emoji: '👑',
          label: 'Last run MVP',
          player: mvp,
          value: '${line.pts} PTS · ${line.wins}-${line.losses}',
        ));
      }
    }
    final scorers = stats.leaders(StatCategory.points);
    if (scorers.isNotEmpty) {
      cards.add(_HighlightCard(
        emoji: '🏀',
        label: 'Scoring leader',
        player: scorers.first.player,
        value: '${formatAvg(scorers.first.value)} PPG',
      ));
    }
    Player? hot;
    var hotN = 1;
    for (final p in store.players) {
      final s = stats.streak(p.id);
      if (s != null && s.startsWith('W')) {
        final n = int.parse(s.substring(1));
        if (n > hotN) {
          hotN = n;
          hot = p;
        }
      }
    }
    if (hot != null) {
      cards.add(_HighlightCard(emoji: '🔥', label: 'On fire', player: hot, value: '$hotN straight wins'));
    }
    final dimes = stats.leaders(StatCategory.assists);
    if (dimes.isNotEmpty) {
      cards.add(_HighlightCard(
        emoji: '🎯',
        label: 'Dime dropper',
        player: dimes.first.player,
        value: '${formatAvg(dimes.first.value)} APG',
      ));
    }
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader('Highlights'),
        SizedBox(
          height: 162,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: cards.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) => cards[i],
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({required this.emoji, required this.label, required this.player, required this.value});
  final String emoji;
  final String label;
  final Player player;
  final String value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 168,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: player.id)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 18)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.7, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                PlayerAvatar(player: player, size: 38),
                const SizedBox(height: 6),
                Text(player.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium),
                Text(value, style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GameDayCard extends StatelessWidget {
  const _GameDayCard({required this.day});
  final GameDay day;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final games = store.gamesFor(day.id);
    final cs = Theme.of(context).colorScheme;
    final mvp = store.player(stats.dayMvp(day.id));
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameDayScreen(dayId: day.id))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(14)),
                child: Column(
                  children: [
                    Text(
                      formatDayShort(day.date).split(' ').first.toUpperCase(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.orange, letterSpacing: 0.8),
                    ),
                    Text('${day.date.day}', style: scoreStyle(28)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            relativeDay(day.date),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (day.videos.isNotEmpty) ...[
                          const Icon(Icons.smart_display_rounded, color: Color(0xFFFF0033), size: 20),
                          const SizedBox(width: 4),
                        ],
                      ],
                    ),
                    Text(
                      [
                        if (day.location != null) day.location!,
                        '${games.length} game${games.length == 1 ? '' : 's'}',
                        '${day.attendeeIds.length} players',
                      ].join(' · '),
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    for (final g in games.take(4)) _MiniScore(box: stats.boxScore(g)),
                    if (mvp != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                          const SizedBox(width: 4),
                          Text('Day MVP: ${mvp.displayName}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
