import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../logic/stats.dart';
import '../../logic/youtube.dart';
import '../../models/game.dart';
import '../../models/game_day.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/game_widgets.dart';
import '../game/game_summary_screen.dart';
import '../game/live_game_screen.dart';
import '../game/team_builder_screen.dart';
import '../players/player_detail_screen.dart';
import '../video/video_screen.dart';
import 'game_day_form.dart';

/// Opens the team builder for the next game of [day].
void openNewGame(BuildContext context, GameDay day, {List<TeamSide>? teams}) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TeamBuilderScreen(dayId: day.id, initialTeams: teams)),
  );
}

void openGame(BuildContext context, Game g) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => g.isLive ? LiveGameScreen(gameId: g.id) : GameSummaryScreen(gameId: g.id),
    ),
  );
}

class GameDayScreen extends StatelessWidget {
  const GameDayScreen({super.key, required this.dayId});
  final String dayId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = context.read<StatsEngine>();
    final day = store.gameDay(dayId);
    if (day == null) return const Scaffold(body: EmptyState(emoji: '🤷', title: 'Run not found'));
    final games = store.gamesFor(day.id);
    final attendees = day.attendeeIds.map(store.player).whereType<Player>().toList();
    final cs = Theme.of(context).colorScheme;
    final hasFinished = games.any((g) => g.isFinished);

    return Scaffold(
      appBar: AppBar(
        title: Text(relativeDay(day.date)),
        actions: [
          IconButton(
            tooltip: 'Share',
            icon: const Icon(Icons.ios_share_rounded),
            onPressed: games.isEmpty ? null : () => _share(context, store, stats, day),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'edit') {
                Navigator.push(context, MaterialPageRoute(builder: (_) => GameDayFormScreen(existing: day)));
              } else if (v == 'notes') {
                _editNotes(context, store, day);
              } else if (v == 'delete') {
                final ok = await confirm(
                  context,
                  title: 'Delete this run?',
                  message: 'All ${games.length} games and their stats will be removed. This cannot be undone.',
                  confirmLabel: 'Delete',
                  destructive: true,
                );
                if (ok && context.mounted) {
                  Navigator.pop(context);
                  store.deleteGameDay(day.id);
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit date, place & players')),
              PopupMenuItem(value: 'notes', child: Text('Notes')),
              PopupMenuItem(value: 'delete', child: Text('Delete run')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          Text(formatDayLong(day.date), style: Theme.of(context).textTheme.headlineMedium),
          if (day.location != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Row(
                children: [
                  Icon(Icons.place_rounded, size: 16, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(day.location!, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GameDayFormScreen(existing: day))),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: AvatarStack(players: attendees, size: 30, max: 9)),
                  Text('${attendees.length} players', style: const TextStyle(fontWeight: FontWeight.w700)),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
          if (day.notes?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Card(
              child: ListTile(
                leading: const Icon(Icons.sticky_note_2_outlined),
                title: Text(day.notes!),
                onTap: () => _editNotes(context, store, day),
              ),
            ),
          ],
          SectionHeader('Games', padding: const EdgeInsets.fromLTRB(4, 24, 0, 10)),
          for (final g in games) ...[
            GameScoreCard(box: stats.boxScore(g), store: store, onTap: () => openGame(context, g)),
            const SizedBox(height: 10),
          ],
          FilledButton.icon(
            icon: const Icon(Icons.add_rounded),
            label: Text(games.isEmpty ? 'Start game 1' : 'New game'),
            onPressed: () => openNewGame(context, day),
          ),
          SectionHeader(
            'Videos',
            padding: const EdgeInsets.fromLTRB(4, 28, 0, 10),
            trailing: TextButton.icon(
              icon: const Icon(Icons.add_link_rounded),
              label: const Text('Add'),
              onPressed: () => addVideo(context, store, day),
            ),
          ),
          if (day.videos.isEmpty)
            _AddVideoPlaceholder(onTap: () => addVideo(context, store, day))
          else
            for (final v in day.videos) ...[
              _VideoCard(day: day, video: v),
              const SizedBox(height: 10),
            ],
          if (hasFinished) ..._dayLeaders(context, store, stats, day),
        ],
      ),
    );
  }

  List<Widget> _dayLeaders(BuildContext context, AppStore store, StatsEngine stats, GameDay day) {
    final totals = stats.dayTotals(day.id);
    final mvp = store.player(stats.dayMvp(day.id));
    final rows = totals.entries.where((e) => store.player(e.key) != null).toList()
      ..sort((a, b) {
        final w = b.value.wins.compareTo(a.value.wins);
        return w != 0 ? w : b.value.pts.compareTo(a.value.pts);
      });
    final cs = Theme.of(context).colorScheme;
    void open(Player p) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerDetailScreen(playerId: p.id)));

    Widget leader(String label, String emoji, int Function(StatLine) get) {
      final best = totals.entries.where((e) => get(e.value) > 0).toList()
        ..sort((a, b) => get(b.value).compareTo(get(a.value)));
      final p = best.isEmpty ? null : store.player(best.first.key);
      return Expanded(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: p == null ? null : () => open(p),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('$emoji $label', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  PlayerAvatar(player: p, size: 36),
                  const SizedBox(height: 4),
                  Text(p?.displayName ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(best.isEmpty ? '' : '${get(best.first.value)}', style: scoreStyle(24, color: AppColors.orange)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return [
      SectionHeader('Day leaders', padding: const EdgeInsets.fromLTRB(4, 28, 0, 10)),
      if (mvp != null)
        Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.gold.withValues(alpha: 0.28), Colors.transparent]),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              leading: PlayerAvatar(player: mvp, size: 48, ring: AppColors.gold),
              title: Text('Day MVP · ${mvp.displayName}', style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Builder(builder: (_) {
                final l = totals[mvp.id]!;
                return Text('${l.wins}-${l.losses} · ${l.pts} PTS · ${l.reb} REB · ${l.ast} AST');
              }),
              trailing: const Text('👑', style: TextStyle(fontSize: 26)),
              onTap: () => open(mvp),
            ),
          ),
        ),
      const SizedBox(height: 10),
      Row(
        children: [
          leader('PTS', '🏀', (l) => l.pts),
          const SizedBox(width: 8),
          leader('REB', '🧲', (l) => l.reb),
          const SizedBox(width: 8),
          leader('AST', '🎯', (l) => l.ast),
        ],
      ),
      const SizedBox(height: 10),
      Card(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(child: Text('PLAYER', style: _head(cs))),
                  SizedBox(width: 48, child: Text('W-L', style: _head(cs), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('PTS', style: _head(cs), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('REB', style: _head(cs), textAlign: TextAlign.center)),
                  SizedBox(width: 40, child: Text('AST', style: _head(cs), textAlign: TextAlign.center)),
                ],
              ),
            ),
            for (final e in rows)
              InkWell(
                onTap: () => open(store.player(e.key)!),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  child: Row(
                    children: [
                      PlayerAvatar(player: store.player(e.key), size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(store.player(e.key)!.displayName,
                            maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text('${e.value.wins}-${e.value.losses}',
                            textAlign: TextAlign.center, style: scoreStyle(17, weight: FontWeight.w800)),
                      ),
                      for (final v in [e.value.pts, e.value.reb, e.value.ast])
                        SizedBox(width: 40, child: Text('$v', textAlign: TextAlign.center, style: scoreStyle(17, weight: FontWeight.w600))),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ];
  }

  TextStyle _head(ColorScheme cs) =>
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: cs.onSurfaceVariant);

  Future<void> _editNotes(BuildContext context, AppStore store, GameDay day) async {
    final c = TextEditingController(text: day.notes ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Notes'),
        content: TextField(
          controller: c,
          maxLines: 5,
          minLines: 3,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Trash talk, injuries, who brought snacks...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (result == null) return;
    day.notes = result.trim().isEmpty ? null : result.trim();
    store.saveGameDay(day);
  }

  void _share(BuildContext context, AppStore store, StatsEngine stats, GameDay day) {
    final b = StringBuffer('🏀 ${store.settings.crewName} · ${formatDay(day.date)}');
    if (day.location != null) b.write(' @ ${day.location}');
    b.writeln();
    for (final g in store.gamesFor(day.id)) {
      final box = stats.boxScore(g);
      final w = box.winner;
      b.writeln('${g.title}: ${g.teams[0].name} ${box.scores[0]} – ${box.scores[1]} ${g.teams[1].name}'
          '${w == null ? '' : '  (${g.teams[w].name} win)'}${g.isLive ? ' [live]' : ''}');
    }
    final mvp = store.player(stats.dayMvp(day.id));
    if (mvp != null) {
      final l = stats.dayTotals(day.id)[mvp.id]!;
      b.writeln('👑 Day MVP: ${mvp.displayName} (${l.pts} pts, ${l.reb} reb, ${l.ast} ast, ${l.wins}-${l.losses})');
    }
    for (final v in day.videos) {
      b.writeln('🎥 ${v.title ?? 'Video'}: ${v.url}');
    }
    SharePlus.instance.share(ShareParams(text: b.toString().trim()));
  }
}

/// Prompts for a YouTube link and attaches it to [day].
Future<void> addVideo(BuildContext context, AppStore store, GameDay day) async {
  final urlC = TextEditingController();
  final titleC = TextEditingController();
  final clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (clip?.text != null && parseYoutubeId(clip!.text!) != null) urlC.text = clip.text!.trim();
  if (!context.mounted) return;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final id = parseYoutubeId(urlC.text);
        return AlertDialog(
          title: const Text('Add YouTube video'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlC,
                autofocus: urlC.text.isEmpty,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://youtu.be/...',
                  prefixIcon: const Icon(Icons.link_rounded),
                  errorText: urlC.text.isNotEmpty && id == null ? "That doesn't look like a YouTube link" : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleC,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(hintText: 'Title (optional), e.g. "Full run, part 1"'),
              ),
              if (id != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.network(
                      youtubeThumbnail(id),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black26),
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: id == null ? null : () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        );
      },
    ),
  );
  if (ok != true) return;
  final id = parseYoutubeId(urlC.text)!;
  day.videos.add(VideoLink(
    id: newId(),
    url: urlC.text.trim(),
    videoId: id,
    title: titleC.text.trim().isEmpty ? null : titleC.text.trim(),
  ));
  store.saveGameDay(day);
}

class _AddVideoPlaceholder extends StatelessWidget {
  const _AddVideoPlaceholder({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cs.outline, width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.smart_display_rounded, color: Color(0xFFFF0033), size: 36),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add the YouTube recording', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(
                    'Paste the link once it is uploaded. Sync it to a game and every play becomes a tap-to-watch highlight.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
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

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.day, required this.video});
  final GameDay day;
  final VideoLink video;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final cs = Theme.of(context).colorScheme;
    void watch() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => VideoScreen(dayId: day.id, videoLinkId: video.id)),
        );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: watch,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    youtubeThumbnail(video.videoId),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: const Icon(Icons.wifi_off_rounded, color: Colors.white38),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                  const Center(child: Icon(Icons.play_circle_fill_rounded, size: 64, color: Colors.white)),
                  Positioned(
                    left: 12,
                    top: 12,
                    child: video.isSynced
                        ? const Pill('SYNCED', color: AppColors.win, filled: true, icon: Icons.link_rounded)
                        : const Pill('NOT SYNCED', color: Colors.black54, filled: true),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      video.title ?? 'Game footage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                    onSelected: (v) async {
                      switch (v) {
                        case 'youtube':
                          await launchUrl(Uri.parse(youtubeWatchUrl(video.videoId)), mode: LaunchMode.externalApplication);
                        case 'rename':
                          final c = TextEditingController(text: video.title ?? '');
                          final t = await showDialog<String>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Video title'),
                              content: TextField(controller: c, autofocus: true),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
                              ],
                            ),
                          );
                          if (t != null) {
                            video.title = t.trim().isEmpty ? null : t.trim();
                            store.saveGameDay(day);
                          }
                        case 'remove':
                          if (await confirm(context, title: 'Remove video?', confirmLabel: 'Remove', destructive: true)) {
                            day.videos.removeWhere((x) => x.id == video.id);
                            store.saveGameDay(day);
                          }
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'youtube', child: Text('Open in YouTube')),
                      PopupMenuItem(value: 'rename', child: Text('Rename')),
                      PopupMenuItem(value: 'remove', child: Text('Remove')),
                    ],
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
