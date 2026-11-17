import 'package:intl/intl.dart';

String formatHeight(double? cm, {required bool metric}) {
  if (cm == null) return '—';
  if (metric) return '${cm.round()} cm';
  final totalIn = (cm / 2.54).round();
  return "${totalIn ~/ 12}'${totalIn % 12}\"";
}

String formatWeight(double? kg, {required bool metric}) {
  if (kg == null) return '—';
  return metric ? '${kg.round()} kg' : '${(kg * 2.20462).round()} lb';
}

double feetInchesToCm(int feet, int inches) => (feet * 12 + inches) * 2.54;
double lbToKg(double lb) => lb / 2.20462;
double kgToLb(double kg) => kg * 2.20462;

String formatPct(double? v) => v == null ? '—' : '${(v * 100).toStringAsFixed(1)}%';

String formatAvg(double v) => v.toStringAsFixed(1);

String madeAttempts(int m, int a) => '$m-$a';

String formatDay(DateTime d) => DateFormat('EEE, MMM d').format(d);
String formatDayLong(DateTime d) => DateFormat('EEEE, MMMM d, y').format(d);
String formatDayShort(DateTime d) => DateFormat('MMM d').format(d);
String formatTime(DateTime d) => DateFormat('h:mm a').format(d);

String relativeDay(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (diff > 1 && diff < 7) return '$diff days ago';
  if (d.year == n.year) return formatDay(d);
  return DateFormat('MMM d, y').format(d);
}

/// Game clock: 605000 ms -> "10:05"; under a minute shows tenths "9.4".
String formatClock(int ms) {
  if (ms < 60000) {
    return (ms / 1000).toStringAsFixed(1);
  }
  final totalS = (ms / 1000).ceil();
  return '${totalS ~/ 60}:${(totalS % 60).toString().padLeft(2, '0')}';
}

String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  return h > 0 ? '${h}h ${m}m' : '${d.inMinutes}m';
}
