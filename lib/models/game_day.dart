/// A YouTube recording attached to a game day.
class VideoLink {
  VideoLink({
    required this.id,
    required this.url,
    required this.videoId,
    this.title,
    this.anchorMs,
  });

  final String id;
  String url;
  String videoId;
  String? title;

  /// Wall-clock time (epoch ms) that corresponds to 0:00 in the video.
  /// Set by "syncing" the video to a game: once known, every play logged in
  /// the app can jump to its exact moment in the recording.
  int? anchorMs;

  bool get isSynced => anchorMs != null;

  /// Seconds into the video for a wall-clock moment, or null if not synced
  /// or the moment is before the recording started.
  int? secondsAt(DateTime moment) {
    if (anchorMs == null) return null;
    final s = (moment.millisecondsSinceEpoch - anchorMs!) ~/ 1000;
    return s < 0 ? null : s;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'videoId': videoId,
        'title': title,
        'anchorMs': anchorMs,
      };

  factory VideoLink.fromJson(Map<String, dynamic> j) => VideoLink(
        id: j['id'] as String,
        url: j['url'] as String,
        videoId: j['videoId'] as String,
        title: j['title'] as String?,
        anchorMs: (j['anchorMs'] as num?)?.toInt(),
      );
}

/// One run / session: a date, who showed up, the games played and videos.
class GameDay {
  GameDay({
    required this.id,
    required this.date,
    this.location,
    this.notes,
    List<String>? attendeeIds,
    List<VideoLink>? videos,
    DateTime? createdAt,
  })  : attendeeIds = attendeeIds ?? <String>[],
        videos = videos ?? <VideoLink>[],
        createdAt = createdAt ?? DateTime.now();

  final String id;
  DateTime date;
  String? location;
  String? notes;
  List<String> attendeeIds;
  List<VideoLink> videos;
  final DateTime createdAt;

  /// The synced video that best covers [moment]: the latest one whose
  /// recording started at or before it.
  VideoLink? videoFor(DateTime moment) {
    VideoLink? best;
    for (final v in videos) {
      final s = v.secondsAt(moment);
      if (s == null) continue;
      if (best == null || v.anchorMs! > best.anchorMs!) best = v;
    }
    return best;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'location': location,
        'notes': notes,
        'attendeeIds': attendeeIds,
        'videos': videos.map((v) => v.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory GameDay.fromJson(Map<String, dynamic> j) => GameDay(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        location: j['location'] as String?,
        notes: j['notes'] as String?,
        attendeeIds: ((j['attendeeIds'] as List?) ?? []).cast<String>(),
        videos: ((j['videos'] as List?) ?? [])
            .map((v) => VideoLink.fromJson((v as Map).cast<String, dynamic>()))
            .toList(),
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );
}
