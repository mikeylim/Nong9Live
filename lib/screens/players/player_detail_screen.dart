import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/photo_store.dart';
import '../../logic/format.dart';
import '../../logic/stats.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../game/game_summary_screen.dart';
import 'player_edit_screen.dart';

class PlayerDetailScreen extends StatefulWidget {
  const PlayerDetailScreen({super.key, required this.playerId});
  final String playerId;

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  StatsRange _range = StatsRange.allTime;
  bool _allGames = false;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final p = store.player(widget.playerId);
    if (p == null) return const Scaffold(body: EmptyState(emoji: '🤷', title: 'Player not found'));
    final line = stats.career(p.id, range: _range);
    final log = stats.gameLog(p.id, range: _range);
    final metric = store.settings.metric;
    final streak = stats.streak(p.id);
    final mates = stats.teammates(p.id);
    final cs = Theme.of(context).colorScheme;

    int high(int Function(StatLine) f) => log.fold<int>(0, (m, l) => f(l.line) > m ? f(l.line) : m);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: Color.lerp(p.color, Colors.black, 0.35),
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_rounded),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerEditScreen(existing: p))),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'archive') {
                    p.archived = !p.archived;
                    store.savePlayer(p);
                  } else if (v == 'delete') {
                    final hasGames = store.playerHasGames(p.id);
                    final ok = await confirm(
                      context,
                      title: hasGames ? 'Archive ${p.name}?' : 'Delete ${p.name}?',
                      message: hasGames
                          ? 'They have played games, so they will be archived (hidden from the roster) '
                              'and their stats stay in old box scores.'
                          : 'This player will be removed.',
                      confirmLabel: hasGames ? 'Archive' : 'Delete',
                      destructive: !hasGames,
                    );
                    if (!ok || !context.mounted) return;
                    if (!hasGames) {
                      Navigator.pop(context);
                      await PhotoStore.delete(p.photoPath);
                    }
                    store.deletePlayer(p.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'archive', child: Text(p.archived ? 'Unarchive' : 'Archive (left the group)')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: _Hero(player: p, metric: metric, streak: streak),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
            sliver: SliverList.list(
              children: [
                SegmentedButton<StatsRange>(
                  segments: [for (final r in StatsRange.values) ButtonSegment(value: r, label: Text(r.label))],
                  selected: {_range},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                ),
                const SizedBox(height: 12),
                if (line.gp == 0)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        _range == StatsRange.allTime ? 'No games yet. Stats show up after their first game.' : 'No games in this period.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ),
                  )
                else ...[
                  _statGrid(line),
                  const SizedBox(height: 10),
                  _badges(context, line, streak, high),
                ],
                if (log.length >= 2) ...[
                  const SectionHeader('Points per game', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
                  _PointsChart(log: log.take(20).toList().reversed.toList()),
                ],
                const SectionHeader('Attributes', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
                _AttributesCard(player: p),
                if (p.strengths.isNotEmpty || p.weaknesses.isNotEmpty) ...[
                  const SectionHeader('Scouting report', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
                  _ScoutingCard(player: p),
                ],
                if (p.bio?.isNotEmpty == true) ...[
                  const SectionHeader('About', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
                  Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(p.bio!, style: const TextStyle(fontSize: 15)))),
                ],
                if (mates.isNotEmpty) ...[
                  const SectionHeader('Best teammates', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
                  Card(
                    child: Column(
                      children: [
                        for (final m in mates.take(4))
                          ListTile(
                            leading: PlayerAvatar(player: m.player, size: 36),
                            title: Text(m.player.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text('${m.wins}-${m.games - m.wins} together'),
                            trailing: Text(formatPct(m.winPct), style: scoreStyle(20, weight: FontWeight.w800)),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: m.player.id)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                if (log.isNotEmpty) ...[
                  const SectionHeader('Game log', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
                  Card(
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        for (final l in (_allGames ? log : log.take(8))) _GameLogRow(line: l),
                        if (log.length > 8)
                          TextButton(
                            onPressed: () => setState(() => _allGames = !_allGames),
                            child: Text(_allGames ? 'Show less' : 'Show all ${log.length} games'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(StatLine l) {
    final boxes = [
      StatBox(label: 'PPG', value: formatAvg(l.per(l.pts)), sub: '${l.pts} total', highlight: true),
      StatBox(label: 'RPG', value: formatAvg(l.per(l.reb)), sub: '${l.reb} total'),
      StatBox(label: 'APG', value: formatAvg(l.per(l.ast)), sub: '${l.ast} total'),
      StatBox(label: 'Record', value: '${l.wins}-${l.losses}', sub: '${formatPct(l.winPct)} wins'),
      StatBox(label: 'SPG', value: formatAvg(l.per(l.stl))),
      StatBox(label: 'BPG', value: formatAvg(l.per(l.blk))),
      StatBox(label: 'FG%', value: formatPct(l.fgPct), sub: '${l.fgm}/${l.fga}'),
      StatBox(label: '3P%', value: formatPct(l.outPct), sub: '${l.outM}/${l.outA}'),
      StatBox(label: 'FT%', value: formatPct(l.ftPct), sub: '${l.ftm}/${l.fta}'),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 8.0;
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [for (final b in boxes) SizedBox(width: w, child: b)],
        );
      },
    );
  }

  Widget _badges(BuildContext context, StatLine l, String? streak, int Function(int Function(StatLine)) high) {
    final chips = <(String, String)>[
      ('📅', '${l.gp} games'),
      if (streak != null && streak.startsWith('W') && streak != 'W1') ('🔥', '$streak streak'),
      if (streak != null && streak.startsWith('L') && streak != 'L1') ('🥶', '$streak skid'),
      if (high((x) => x.pts) > 0) ('🏀', 'High ${high((x) => x.pts)} pts'),
      if (high((x) => x.reb) > 0) ('🧲', 'High ${high((x) => x.reb)} reb'),
      if (high((x) => x.ast) > 0) ('🎯', 'High ${high((x) => x.ast)} ast'),
      if (l.airballs > 0) ('💨', '${l.airballs} airball${l.airballs == 1 ? '' : 's'}'),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final (e, t) in chips) Chip(avatar: Text(e), label: Text(t), visualDensity: VisualDensity.compact)],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.player, required this.metric, required this.streak});
  final Player player;
  final bool metric;
  final String? streak;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final facts = <String>[
      if (p.heightCm != null) formatHeight(p.heightCm, metric: metric),
      if (p.weightKg != null) formatWeight(p.weightKg, metric: metric),
      if (p.hand != null) p.hand == 'L' ? 'Lefty' : 'Righty',
    ];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [p.color, Color.lerp(p.color, Colors.black, 0.6)!],
        ),
      ),
      child: Stack(
        children: [
          if (p.jerseyNumber != null)
            Positioned(
              right: 12,
              bottom: 8,
              child: Text('${p.jerseyNumber}', style: scoreStyle(150, color: Colors.white.withValues(alpha: 0.12))),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PlayerAvatar(player: p, size: 104, ring: Colors.white),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OvrBadge(overall: p.overall, size: 1.1, onColor: true),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: displayFont,
                            fontWeight: FontWeight.w900,
                            fontSize: 32,
                            height: 1,
                            color: Colors.white,
                          ),
                        ),
                        if (p.nickname?.isNotEmpty == true)
                          Text('"${p.nickname}"',
                              style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (p.jerseyNumber != null) _heroChip('#${p.jerseyNumber}'),
                            for (final pos in (p.positions.toList()..sort((a, b) => a.index.compareTo(b.index))))
                              _heroChip(pos.label),
                            for (final f in facts) _heroChip(f),
                            if (p.archived) _heroChip('Archived'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroChip(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.5)),
      );
}

class _PointsChart extends StatelessWidget {
  const _PointsChart({required this.log});

  /// Oldest first.
  final List<PlayerGameLine> log;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final series = chartSeriesColor(Theme.of(context).brightness);
    final maxPts = log.map((l) => l.line.pts).fold<int>(0, (a, b) => a > b ? a : b);
    final top = ((maxPts / 5).ceil() * 5).clamp(5, 200).toDouble();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
        child: SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: top,
              minX: 0,
              maxX: (log.length - 1).toDouble(),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: top <= 10 ? 2 : 5,
                getDrawingHorizontalLine: (_) => FlLine(color: cs.outlineVariant, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                bottomTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: top <= 10 ? 2 : 5,
                    getTitlesWidget: (v, meta) => SideTitleWidget(
                      meta: meta,
                      child: Text('${v.toInt()}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    ),
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => cs.inverseSurface,
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        '${log[s.x.toInt()].line.pts} pts\n${formatDayShort(log[s.x.toInt()].when)}',
                        TextStyle(color: cs.onInverseSurface, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: [for (var i = 0; i < log.length; i++) FlSpot(i.toDouble(), log[i].line.pts.toDouble())],
                  isCurved: true,
                  preventCurveOverShooting: true,
                  color: series,
                  barWidth: 2,
                  dotData: FlDotData(
                    getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                      radius: 4,
                      color: series,
                      strokeWidth: 2,
                      strokeColor: cs.surfaceContainer,
                    ),
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [series.withValues(alpha: 0.22), series.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AttributesCard extends StatelessWidget {
  const _AttributesCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final series = chartSeriesColor(Theme.of(context).brightness);
    final attrs = Attribute.values;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
        child: Row(
          children: [
            Expanded(
              flex: 5,
              child: AspectRatio(
                aspectRatio: 1,
                child: RadarChart(
                  RadarChartData(
                    radarShape: RadarShape.polygon,
                    dataSets: [
                      RadarDataSet(
                        dataEntries: [for (final a in attrs) RadarEntry(value: (player.ratings[a] ?? 5).toDouble())],
                        fillColor: series.withValues(alpha: 0.25),
                        borderColor: series,
                        borderWidth: 2,
                        entryRadius: 4,
                      ),
                      // Invisible bounds so the scale is always 0..10.
                      RadarDataSet(
                        dataEntries: [for (final _ in attrs) const RadarEntry(value: 10)],
                        fillColor: Colors.transparent,
                        borderColor: Colors.transparent,
                        entryRadius: 0,
                      ),
                      RadarDataSet(
                        dataEntries: [for (final _ in attrs) const RadarEntry(value: 0)],
                        fillColor: Colors.transparent,
                        borderColor: Colors.transparent,
                        entryRadius: 0,
                      ),
                    ],
                    radarBackgroundColor: Colors.transparent,
                    radarBorderData: BorderSide(color: cs.outline, width: 1),
                    gridBorderData: BorderSide(color: cs.outlineVariant, width: 1),
                    tickBorderData: BorderSide(color: cs.outlineVariant, width: 1),
                    tickCount: 4,
                    ticksTextStyle: const TextStyle(color: Colors.transparent, fontSize: 1),
                    titleTextStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w800),
                    titlePositionPercentageOffset: 0.12,
                    getTitle: (i, _) => RadarChartTitle(text: attrs[i].short),
                    radarTouchData: RadarTouchData(enabled: false),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  for (final a in attrs)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          ),
                          Text('${player.ratings[a] ?? 5}', style: scoreStyle(18, weight: FontWeight.w800)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoutingCard extends StatelessWidget {
  const _ScoutingCard({required this.player});
  final Player player;

  @override
  Widget build(BuildContext context) {
    Widget group(String title, IconData icon, Color color, List<String> items) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final s in items)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
              ],
            ),
          ],
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (player.strengths.isNotEmpty) group('Strengths', Icons.trending_up_rounded, AppColors.win, player.strengths),
            if (player.strengths.isNotEmpty && player.weaknesses.isNotEmpty) const SizedBox(height: 16),
            if (player.weaknesses.isNotEmpty)
              group('Work on', Icons.construction_rounded, AppColors.foul, player.weaknesses),
          ],
        ),
      ),
    );
  }
}

class _GameLogRow extends StatelessWidget {
  const _GameLogRow({required this.line});
  final PlayerGameLine line;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l = line.line;
    final team = line.game.teams[line.team];
    final (label, color) = switch (line.result) {
      GameResult.win => ('W', AppColors.win),
      GameResult.loss => ('L', AppColors.loss),
      _ => ('T', cs.onSurfaceVariant),
    };
    final mine = line.score[line.team], theirs = line.score[1 - line.team];
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => GameSummaryScreen(gameId: line.game.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(8)),
              child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${formatDayShort(line.when)} · ${line.game.title}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Row(
                    children: [
                      TeamSwatch(color: team.color, size: 10),
                      const SizedBox(width: 4),
                      Text('${team.name} $mine-$theirs', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                    ],
                  ),
                ],
              ),
            ),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: '${l.pts}', style: scoreStyle(20, color: AppColors.orange)),
                TextSpan(text: ' pts  ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                TextSpan(text: '${l.reb}', style: scoreStyle(17, weight: FontWeight.w800)),
                TextSpan(text: ' reb  ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                TextSpan(text: '${l.ast}', style: scoreStyle(17, weight: FontWeight.w800)),
                TextSpan(text: ' ast', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
