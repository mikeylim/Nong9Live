import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../logic/play_text.dart';
import '../../logic/youtube.dart';
import '../../models/game.dart';
import '../../models/game_day.dart';
import '../../models/game_event.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Watches a game day's YouTube recording. Once synced, every logged play
/// becomes a jump-to moment in the video.
class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key, required this.dayId, required this.videoLinkId, this.startAt, this.focusGameId});
  final String dayId;
  final String videoLinkId;

  /// Wall-clock moment to jump to (works once the video is synced).
  final DateTime? startAt;
  final String? focusGameId;

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late final YoutubePlayerController _yt;
  String? _gameFilter;
  String? _playerFilter;
  bool _highlightsOnly = true;

  /// Seconds of lead-in before a play, so you see it develop.
  static const _leadIn = 5;

  AppStore get _store => context.read<AppStore>();

  @override
  void initState() {
    super.initState();
    final video = _video!;
    _gameFilter = widget.focusGameId;
    final s = widget.startAt == null ? null : video.secondsAt(widget.startAt!);
    _yt = YoutubePlayerController.fromVideoId(
      videoId: video.videoId,
      autoPlay: true,
      startSeconds: s == null ? null : (s - _leadIn).clamp(0, 1 << 30).toDouble(),
      params: const YoutubePlayerParams(showFullscreenButton: true, strictRelatedVideos: true),
    );
  }

  @override
  void dispose() {
    _yt.close();
    super.dispose();
  }

  GameDay? get _day => _store.gameDay(widget.dayId);
  VideoLink? get _video => _day?.videos.where((v) => v.id == widget.videoLinkId).firstOrNull;

  Future<void> _seek(int seconds) async {
    await _yt.seekTo(seconds: (seconds - _leadIn).clamp(0, 1 << 30).toDouble(), allowSeekAhead: true);
    await _yt.playVideo();
  }

  void _setAnchor(DateTime moment, double videoSeconds) {
    final day = _day!;
    final v = _video!;
    v.anchorMs = moment.millisecondsSinceEpoch - (videoSeconds * 1000).round();
    _store.saveGameDay(day);
    toast(context, 'Synced! Tap any play to jump to it.');
  }

  /// "What is happening right now in the video?" → anchor.
  Future<void> _sync() async {
    await _yt.pauseVideo();
    final now = await _yt.currentTime;
    if (!mounted) return;
    final day = _day!;
    final games = _store.gamesFor(day.id).where((g) => g.startedAt != null).toList();
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _SyncSheet(videoSeconds: now, games: games, store: _store),
    );
    if (picked != null) _setAnchor(picked, now);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final day = store.gameDay(widget.dayId);
    final video = _video;
    if (day == null || video == null) return const Scaffold(body: SizedBox.shrink());
    final games = store.gamesFor(day.id);
    final cs = Theme.of(context).colorScheme;
    final players = {for (final g in games) ...g.allPlayerIds}.map(store.player).whereType<Player>().toList()
      ..sort((a, b) => a.displayName.compareTo(b.displayName));

    return Scaffold(
      appBar: AppBar(
        title: Text(video.title ?? 'Game footage', overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Open in YouTube',
            icon: const Icon(Icons.open_in_new_rounded),
            onPressed: () async {
              final t = await _yt.currentTime;
              await launchUrl(
                Uri.parse(youtubeWatchUrl(video.videoId, seconds: t.floor())),
                mode: LaunchMode.externalApplication,
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          YoutubePlayer(controller: _yt, aspectRatio: 16 / 9),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (day.videos.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final v in day.videos)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              avatar: const Icon(Icons.smart_display_rounded, size: 18),
                              label: Text(v.title ?? 'Video ${day.videos.indexOf(v) + 1}'),
                              selected: v.id == video.id,
                              onSelected: (_) => Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (_) => VideoScreen(dayId: day.id, videoLinkId: v.id)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _syncCard(video, cs),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FilterChip(
                        label: const Text('Highlights'),
                        selected: _highlightsOnly,
                        onSelected: (v) => setState(() => _highlightsOnly = v),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('All games'),
                        selected: _gameFilter == null,
                        onSelected: (_) => setState(() => _gameFilter = null),
                      ),
                      for (final g in games) ...[
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: Text(g.title),
                          selected: _gameFilter == g.id,
                          onSelected: (_) => setState(() => _gameFilter = g.id),
                        ),
                      ],
                    ],
                  ),
                ),
                if (players.isNotEmpty)
                  SizedBox(
                    height: 58,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(top: 8),
                      children: [
                        for (final p in players)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              avatar: PlayerAvatar(player: p, size: 24),
                              label: Text(p.displayName),
                              selected: _playerFilter == p.id,
                              onSelected: (v) => setState(() => _playerFilter = v ? p.id : null),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                for (final g in games)
                  if (_gameFilter == null || _gameFilter == g.id) ..._moments(g, video, cs),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _syncCard(VideoLink video, ColorScheme cs) {
    if (video.isSynced) {
      final zero = DateTime.fromMillisecondsSinceEpoch(video.anchorMs!);
      return Card(
        child: ListTile(
          leading: const Icon(Icons.link_rounded, color: AppColors.win),
          title: const Text('Synced with the scoresheet', style: TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text('Video starts at ${formatTime(zero)}. Tap a play to jump there.'),
          trailing: TextButton(onPressed: _sync, child: const Text('Re-sync')),
        ),
      );
    }
    return Card(
      color: AppColors.orange.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🔗 Sync the video to your stats', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              'Scrub the video to a tip-off (or any play you logged), then tap Sync. '
              'After that, every play below jumps straight to its moment.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(onPressed: _sync, icon: const Icon(Icons.sync_rounded), label: const Text('Sync now')),
          ],
        ),
      ),
    );
  }

  List<Widget> _moments(Game g, VideoLink video, ColorScheme cs) {
    final store = _store;
    final events = store.eventsFor(g.id);
    final running = runningScores(events);
    final out = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
        child: Row(
          children: [
            TeamSwatch(color: g.teams[0].color, size: 12),
            const SizedBox(width: 4),
            TeamSwatch(color: g.teams[1].color, size: 12),
            const SizedBox(width: 8),
            Text(g.title.toUpperCase(),
                style: TextStyle(fontFamily: displayFont, fontWeight: FontWeight.w800, fontSize: 16, color: cs.onSurfaceVariant)),
            const Spacer(),
            if (g.startedAt != null && video.secondsAt(g.startedAt!) != null)
              TextButton.icon(
                onPressed: () => _seek(video.secondsAt(g.startedAt!)!),
                icon: const Icon(Icons.play_arrow_rounded),
                label: Text('Tip-off ${formatVideoTime(video.secondsAt(g.startedAt!)!)}'),
              ),
          ],
        ),
      ),
    ];
    var shown = 0;
    for (var i = 0; i < events.length; i++) {
      final e = events[i];
      if (e.type == EventType.assist && e.linkedId != null) continue;
      if (_playerFilter != null && e.playerId != _playerFilter) {
        // keep assists by the filtered player visible through their shot
        final assist = events.where((x) => x.linkedId == e.id && x.type == EventType.assist && x.playerId == _playerFilter);
        if (assist.isEmpty) continue;
      }
      final highlight = e.points > 0 || e.airball || e.type == EventType.block || e.type == EventType.steal;
      if (_highlightsOnly && !highlight) continue;
      final assist = events.where((x) => x.linkedId == e.id && x.type == EventType.assist).firstOrNull;
      final sec = video.secondsAt(e.at);
      shown++;
      out.add(
        Card(
          margin: const EdgeInsets.only(bottom: 6),
          child: ListTile(
            dense: true,
            leading: Container(
              width: 6,
              height: 28,
              decoration: BoxDecoration(
                color: visibleTeamColorIn(context, g.teams[e.team].color),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            title: Text(
              playText(e, g, store.player(e.playerId), assist: store.player(assist?.playerId)),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            subtitle: Text('${running[i][0]}-${running[i][1]} · ${formatTime(e.at)}'),
            trailing: sec == null
                ? null
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(formatVideoTime(sec), style: const TextStyle(color: AppColors.orange, fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      const Icon(Icons.play_circle_fill_rounded, color: AppColors.orange),
                    ],
                  ),
            onTap: sec != null ? () => _seek(sec) : () => toast(context, 'Sync the video first to jump to plays.'),
            onLongPress: () async {
              final ok = await confirm(
                context,
                title: 'Sync to this play?',
                message: 'Use this if the video is paused exactly at this play.',
                confirmLabel: 'Sync here',
              );
              if (!ok) return;
              final t = await _yt.currentTime;
              _setAnchor(e.at, t);
            },
          ),
        ),
      );
    }
    if (shown == 0) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
        child: Text('No matching plays.', style: TextStyle(color: cs.onSurfaceVariant)),
      ));
    }
    return out;
  }
}

class _SyncSheet extends StatelessWidget {
  const _SyncSheet({required this.videoSeconds, required this.games, required this.store});
  final double videoSeconds;
  final List<Game> games;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('What happens at ${formatVideoTime(videoSeconds.floor())}?', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text('Pick the moment the video is paused on.', style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            for (final g in games) ...[
              Card(
                child: ListTile(
                  leading: const Text('🏀', style: TextStyle(fontSize: 22)),
                  title: Text('${g.title} tip-off', style: const TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: Text('${g.teams[0].name} vs ${g.teams[1].name} · ${formatTime(g.startedAt!)}'),
                  onTap: () => Navigator.pop(context, g.startedAt),
                ),
              ),
              for (final e in store.eventsFor(g.id).where((e) => e.points > 0).take(6))
                ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.only(left: 32, right: 8),
                  title: Text(playText(e, g, store.player(e.playerId))),
                  subtitle: Text(formatTime(e.at)),
                  onTap: () => Navigator.pop(context, e.at),
                ),
              const SizedBox(height: 6),
            ],
          ],
        ),
      ),
    );
  }
}
