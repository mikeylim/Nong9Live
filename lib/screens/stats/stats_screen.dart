import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../logic/stats.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../game/game_summary_screen.dart';
import '../players/player_detail_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatCategory _cat = StatCategory.points;
  StatsRange _range = StatsRange.allTime;

  void _open(String id) => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: id)));

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final cs = Theme.of(context).colorScheme;
    if (!store.allGames.any((g) => g.isFinished)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Leaderboards')),
        body: const EmptyState(
          emoji: '📊',
          title: 'No stats yet',
          message: 'Finish a game and the leaderboards, records and player stats fill in automatically.',
        ),
      );
    }
    final rows = stats.leaders(_cat, range: _range);
    final records = stats.records(range: _range);
    final minGames = store.settings.minGamesForLeaders;

    return Scaffold(
      appBar: AppBar(title: Text(_cat.isShame ? 'Hall of shame 🤡' : 'Leaderboards')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: SegmentedButton<StatsRange>(
                segments: [for (final r in StatsRange.values) ButtonSegment(value: r, label: Text(r.label))],
                selected: {_range},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _range = s.first),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: StatCategory.values.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final c = StatCategory.values[i];
                  return ChoiceChip(
                    label: Text('${c.emoji} ${c.short}'),
                    selected: c == _cat,
                    onSelected: (_) => setState(() => _cat = c),
                  );
                },
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                _cat.label,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          if (rows.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _cat.isShame
                      ? 'Nobody yet. Clean game! 😇'
                      : 'Nobody qualifies yet (needs $minGames+ games${_cat.isPercent ? ' and enough attempts' : ''}).',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: _Podium(rows: rows.take(3).toList(), cat: _cat, onTap: _open)),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList.builder(
                itemCount: rows.length > 3 ? rows.length - 3 : 0,
                itemBuilder: (context, i) {
                  final r = rows[i + 3];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      onTap: () => _open(r.player.id),
                      leading: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text('${i + 4}', style: scoreStyle(18, color: cs.onSurfaceVariant, weight: FontWeight.w800)),
                          ),
                          PlayerAvatar(player: r.player, size: 36),
                        ],
                      ),
                      title: Text(r.player.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(_cat.detail(r.line)),
                      trailing: Text(_cat.format(r.value), style: scoreStyle(24, weight: FontWeight.w800)),
                    ),
                  );
                },
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Text(
                'Averages need $minGames+ games. FG% needs 10+ attempts, 3P% and FT% need 5+. Change the minimum in Settings.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ),
          if (records.isNotEmpty) ...[
            const SliverToBoxAdapter(child: SectionHeader('Single-game records')),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              sliver: SliverList.builder(
                itemCount: records.length,
                itemBuilder: (context, i) {
                  final r = records[i];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => GameSummaryScreen(gameId: r.gameLine.game.id)),
                      ),
                      leading: Text(r.emoji, style: const TextStyle(fontSize: 26)),
                      title: Text(r.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Row(
                        children: [
                          PlayerAvatar(player: r.player, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${r.player.displayName} · ${formatDayShort(r.gameLine.when)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text('${r.value}', style: scoreStyle(28, color: AppColors.orange)),
                    ),
                  );
                },
              ),
            ),
          ] else
            const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.rows, required this.cat, required this.onTap});
  final List<LeaderRow> rows;
  final StatCategory cat;
  final void Function(String) onTap;

  static const _medal = [Color(0xFFFFC83D), Color(0xFFC0C7D2), Color(0xFFD08A4E)];

  @override
  Widget build(BuildContext context) {
    // Visual order: 2nd, 1st, 3rd.
    final order = [if (rows.length > 1) 1, 0, if (rows.length > 2) 2];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final rank in order)
            Expanded(
              child: GestureDetector(
                onTap: () => onTap(rows[rank].player.id),
                child: _step(context, rows[rank], rank),
              ),
            ),
        ],
      ),
    );
  }

  Widget _step(BuildContext context, LeaderRow r, int rank) {
    final cs = Theme.of(context).colorScheme;
    final heights = [118.0, 88.0, 70.0];
    final avatar = rank == 0 ? 76.0 : 58.0;
    return Column(
      children: [
        if (rank == 0) Text(cat.isShame ? '🤡' : '👑', style: const TextStyle(fontSize: 26)),
        PlayerAvatar(player: r.player, size: avatar, ring: _medal[rank]),
        const SizedBox(height: 6),
        Text(
          r.player.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
        ),
        Text(cat.detail(r.line), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        Container(
          height: heights[rank],
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_medal[rank].withValues(alpha: 0.55), _medal[rank].withValues(alpha: 0.12)],
            ),
          ),
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            children: [
              Text(cat.format(r.value), style: scoreStyle(rank == 0 ? 30 : 24, color: cs.onSurface)),
              Text(cat.short, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}
