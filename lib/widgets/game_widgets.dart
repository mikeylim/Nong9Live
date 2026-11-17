import 'package:flutter/material.dart';

import '../data/app_store.dart';
import '../logic/stats.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import 'common.dart';

/// Compact card showing a game's two teams and score.
class GameScoreCard extends StatelessWidget {
  const GameScoreCard({super.key, required this.box, required this.store, this.onTap});
  final BoxScore box;
  final AppStore store;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final g = box.game;
    final cs = Theme.of(context).colorScheme;
    final mvp = store.player(box.mvpId);
    final mvpLine = mvp == null ? null : box.lineFor(mvp.id);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    g.title.toUpperCase(),
                    style: TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 1,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(g.rules.summary, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  if (g.isLive) const LivePill() else Pill('FINAL', color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 10),
              for (var t = 0; t < 2; t++) _teamRow(context, t),
              if (mvp != null && mvpLine != null && g.isFinished) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star_rounded, color: AppColors.gold, size: 18),
                    const SizedBox(width: 4),
                    Text('MVP ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: cs.onSurfaceVariant)),
                    Expanded(
                      child: Text(
                        '${mvp.displayName} · ${mvpLine.pts} PTS · ${mvpLine.reb} REB · ${mvpLine.ast} AST',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _teamRow(BuildContext context, int t) {
    final g = box.game;
    final team = g.teams[t];
    final cs = Theme.of(context).colorScheme;
    final won = box.winner == t;
    final lost = box.winner != null && box.winner != t;
    final players = team.playerIds.map(store.player).whereType<Player>().toList();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          TeamSwatch(color: team.color, size: 16),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              team.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 17,
                fontWeight: won ? FontWeight.w800 : FontWeight.w600,
                color: lost ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: AvatarStack(players: players, size: 22)),
          if (won) const Padding(padding: EdgeInsets.only(right: 6), child: Text('🏆', style: TextStyle(fontSize: 16))),
          Text(
            '${box.scores[t]}',
            style: scoreStyle(30, color: lost ? cs.onSurfaceVariant : cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.players, this.size = 26, this.max = 6});
  final List<Player> players;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = players.take(max).toList();
    final extra = players.length - shown.length;
    final bg = Theme.of(context).colorScheme.surfaceContainer;
    return SizedBox(
      height: size + 4,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * size * 0.78,
              child: PlayerAvatar(player: shown[i], size: size, ring: bg),
            ),
          if (extra > 0)
            Positioned(
              left: (shown.length - 1) * size * 0.78 + size + 8,
              top: size * 0.18,
              child: Text('+$extra', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

/// Box score for one team with a frozen name column.
class BoxScoreTable extends StatelessWidget {
  const BoxScoreTable({super.key, required this.box, required this.team, required this.store, this.onPlayerTap});
  final BoxScore box;
  final int team;
  final AppStore store;
  final void Function(Player)? onPlayerTap;

  static const _rowH = 46.0;
  static const _headH = 34.0;
  static const _nameW = 138.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final side = box.game.teams[team];
    final scoring = box.game.rules.scoring;
    final entries = box.players[team].entries.toList()
      ..sort((a, b) => b.value.pts.compareTo(a.value.pts));
    final totals = box.teamTotals[team];

    final cols = <(String, double, String Function(StatLine))>[
      ('PTS', 44, (l) => '${l.pts}'),
      ('REB', 42, (l) => '${l.reb}'),
      ('AST', 42, (l) => '${l.ast}'),
      ('STL', 42, (l) => '${l.stl}'),
      ('BLK', 42, (l) => '${l.blk}'),
      ('TO', 38, (l) => '${l.tov}'),
      ('PF', 38, (l) => '${l.pf}'),
      ('FG', 56, (l) => '${l.fgm}-${l.fga}'),
      (scoring == ScoringMode.standard ? '3P' : 'LONG', 56, (l) => '${l.outM}-${l.outA}'),
      ('FT', 52, (l) => '${l.ftm}-${l.fta}'),
    ];

    TextStyle head = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: cs.onSurfaceVariant);
    Widget cell(String text, double w, {bool bold = false, Color? color}) => SizedBox(
          width: w,
          height: _rowH,
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontFamily: displayFont,
                fontSize: 17,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        );

    final isMvp = box.mvpId;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: side.color.withValues(alpha: 0.9),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Text(
                  side.name.toUpperCase(),
                  style: TextStyle(
                    fontFamily: displayFont,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    letterSpacing: 1,
                    color: side.onColor,
                  ),
                ),
                const Spacer(),
                Text('${box.scores[team]}', style: scoreStyle(22, color: side.onColor)),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _nameW,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: _headH,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Align(alignment: Alignment.centerLeft, child: Text('PLAYER', style: head)),
                      ),
                    ),
                    for (final e in entries)
                      InkWell(
                        onTap: store.player(e.key) == null || onPlayerTap == null
                            ? null
                            : () => onPlayerTap!(store.player(e.key)!),
                        child: SizedBox(
                          height: _rowH,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Row(
                              children: [
                                PlayerAvatar(player: store.player(e.key), size: 26),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    store.player(e.key)?.displayName ?? 'Unknown',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                                ),
                                if (isMvp == e.key)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 2, right: 4),
                                    child: Icon(Icons.star_rounded, color: AppColors.gold, size: 16),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Container(
                      height: _rowH,
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
                      padding: const EdgeInsets.only(left: 14),
                      alignment: Alignment.centerLeft,
                      child: Text('TEAM', style: head.copyWith(color: cs.onSurface)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        height: _headH,
                        child: Row(
                          children: [
                            for (final c in cols) SizedBox(width: c.$2, child: Center(child: Text(c.$1, style: head))),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                      for (final e in entries)
                        Row(
                          children: [
                            for (var i = 0; i < cols.length; i++)
                              cell(cols[i].$3(e.value), cols[i].$2, bold: i == 0, color: i == 0 ? AppColors.orange : null),
                          ],
                        ),
                      Container(
                        decoration: BoxDecoration(border: Border(top: BorderSide(color: cs.outlineVariant))),
                        child: Row(
                          children: [
                            for (var i = 0; i < cols.length; i++) cell(cols[i].$3(totals), cols[i].$2, bold: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
