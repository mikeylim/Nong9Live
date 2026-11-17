/// Extracts the 11-character video id from any common YouTube link
/// (watch, youtu.be, shorts, live, embed, mobile, music) or a bare id.
String? parseYoutubeId(String input) {
  final text = input.trim();
  final idPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (idPattern.hasMatch(text)) return text;

  final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
  if (uri == null || uri.host.isEmpty) return null;
  final host = uri.host.toLowerCase().replaceFirst('www.', '').replaceFirst('m.', '');

  String? candidate;
  if (host == 'youtu.be') {
    candidate = uri.pathSegments.firstOrNull;
  } else if (host.endsWith('youtube.com') || host.endsWith('youtube-nocookie.com')) {
    candidate = uri.queryParameters['v'];
    if (candidate == null && uri.pathSegments.length >= 2) {
      const prefixes = {'shorts', 'live', 'embed', 'v', 'e'};
      if (prefixes.contains(uri.pathSegments.first)) candidate = uri.pathSegments[1];
    }
  }
  if (candidate == null) return null;
  return idPattern.hasMatch(candidate) ? candidate : null;
}

/// Start time encoded in a link (`t=90`, `t=1m30s`, `start=90`).
int? parseYoutubeStart(String input) {
  final uri = Uri.tryParse(input.trim());
  final t = uri?.queryParameters['t'] ?? uri?.queryParameters['start'];
  if (t == null) return null;
  final plain = int.tryParse(t.replaceAll('s', ''));
  if (plain != null) return plain;
  final m = RegExp(r'^(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?$').firstMatch(t);
  if (m == null) return null;
  final h = int.tryParse(m.group(1) ?? '') ?? 0;
  final min = int.tryParse(m.group(2) ?? '') ?? 0;
  final s = int.tryParse(m.group(3) ?? '') ?? 0;
  return h * 3600 + min * 60 + s;
}

String youtubeThumbnail(String id) => 'https://img.youtube.com/vi/$id/hqdefault.jpg';

String youtubeWatchUrl(String id, {int? seconds}) =>
    'https://www.youtube.com/watch?v=$id${seconds != null && seconds > 0 ? '&t=${seconds}s' : ''}';

/// 75 -> "1:15", 3725 -> "1:02:05".
String formatVideoTime(int seconds) {
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  String two(int v) => v.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

/// Parses "1:02:05", "12:34", "754" or "12m34s" into seconds.
int? parseVideoTime(String input) {
  final t = input.trim();
  if (t.isEmpty) return null;
  if (RegExp(r'^\d+$').hasMatch(t)) return int.parse(t);
  final colon = RegExp(r'^(?:(\d+):)?(\d{1,2}):(\d{2})$').firstMatch(t);
  if (colon != null) {
    final h = int.tryParse(colon.group(1) ?? '') ?? 0;
    final m = int.parse(colon.group(2)!);
    final s = int.parse(colon.group(3)!);
    if (s >= 60) return null;
    return h * 3600 + m * 60 + s;
  }
  final units = RegExp(r'^(?:(\d+)h)?\s*(?:(\d+)m)?\s*(?:(\d+)s)?$').firstMatch(t);
  if (units != null && (units.group(1) ?? units.group(2) ?? units.group(3)) != null) {
    return (int.tryParse(units.group(1) ?? '') ?? 0) * 3600 +
        (int.tryParse(units.group(2) ?? '') ?? 0) * 60 +
        (int.tryParse(units.group(3) ?? '') ?? 0);
  }
  return null;
}
