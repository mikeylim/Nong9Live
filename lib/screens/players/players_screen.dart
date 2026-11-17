import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../logic/stats.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'player_detail_screen.dart';
import 'player_edit_screen.dart';

class PlayersScreen extends StatefulWidget {
  const PlayersScreen({super.key});

  @override
  State<PlayersScreen> createState() => _PlayersScreenState();
}

class _PlayersScreenState extends State<PlayersScreen> {
  String _query = '';
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final all = _showArchived ? store.allPlayers : store.players;
    final q = _query.toLowerCase();
    final players = all
        .where((p) =>
            q.isEmpty ||
            p.name.toLowerCase().contains(q) ||
            (p.nickname?.toLowerCase().contains(q) ?? false) ||
            '${p.jerseyNumber ?? ''}' == q)
        .toList();
    final hasArchived = store.allPlayers.any((p) => p.archived);

    return Scaffold(
      appBar: AppBar(
        title: Text('Players · ${store.players.length}'),
        actions: [
          if (hasArchived)
            IconButton(
              tooltip: _showArchived ? 'Hide archived' : 'Show archived',
              icon: Icon(_showArchived ? Icons.inventory_2_rounded : Icons.inventory_2_outlined),
              onPressed: () => setState(() => _showArchived = !_showArchived),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerEditScreen())),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add player'),
      ),
      body: all.isEmpty
          ? EmptyState(
              emoji: '👟',
              title: 'Build your roster',
              message: 'Add everyone in your run. Each player gets a card with position, size, '
                  'strengths & weaknesses, and stats that build up every week.',
              action: FilledButton.icon(
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Add first player'),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlayerEditScreen())),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Search name, nickname or #'),
                      onChanged: (v) => setState(() => _query = v.trim()),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  sliver: SliverGrid.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 236,
                    ),
                    itemCount: players.length,
                    itemBuilder: (context, i) => _PlayerCard(player: players[i], line: stats.career(players[i].id)),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Trading-card style tile.
class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.player, required this.line});
  final Player player;
  final StatLine line;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final p = player;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: p.id))),
        child: Opacity(
          opacity: p.archived ? 0.55 : 1,
          child: Column(
            children: [
              SizedBox(
                height: 104,
                child: Stack(
                  children: [
                    Positioned.fill(
                      bottom: 34,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [p.color, Color.lerp(p.color, Colors.black, 0.45)!],
                          ),
                        ),
                      ),
                    ),
                    if (p.jerseyNumber != null)
                      Positioned(
                        right: 10,
                        top: 4,
                        child: Text(
                          '${p.jerseyNumber}',
                          style: scoreStyle(40, color: Colors.white.withValues(alpha: 0.35)),
                        ),
                      ),
                    Positioned(left: 10, top: 8, child: OvrBadge(overall: p.overall, size: 0.85, onColor: true)),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: PlayerAvatar(player: p, size: 64, ring: cs.surfaceContainer),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                child: Column(
                  children: [
                    Text(
                      p.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      [
                        if (p.nickname?.isNotEmpty == true) p.name,
                        if (p.positionLabel.isNotEmpty) p.positionLabel,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                child: line.gp == 0
                    ? Text('No games yet', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _mini('PPG', formatAvg(line.per(line.pts)), cs),
                          _mini('RPG', formatAvg(line.per(line.reb)), cs),
                          _mini('APG', formatAvg(line.per(line.ast)), cs),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mini(String label, String value, ColorScheme cs) => Expanded(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            children: [
              Text(value, style: scoreStyle(20, weight: FontWeight.w800)),
              Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
}
