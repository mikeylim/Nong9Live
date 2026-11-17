import 'package:flutter_test/flutter_test.dart';
import 'package:nong9live/logic/youtube.dart';
import 'package:nong9live/models/game_day.dart';

void main() {
  group('parseYoutubeId', () {
    const id = 'dQw4w9WgXcQ';
    for (final url in [
      id,
      'https://www.youtube.com/watch?v=$id',
      'https://youtube.com/watch?v=$id&t=42s',
      'https://m.youtube.com/watch?v=$id&feature=share',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc123&t=10',
      'youtu.be/$id',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id?si=x',
      'https://www.youtube.com/embed/$id',
      'https://www.youtube-nocookie.com/embed/$id',
      'https://music.youtube.com/watch?v=$id',
      '  https://youtu.be/$id  ',
    ]) {
      test(url, () => expect(parseYoutubeId(url), id));
    }

    for (final bad in [
      '',
      'hello',
      'https://vimeo.com/123456',
      'https://www.youtube.com/watch?v=short',
      'https://www.youtube.com/@somechannel',
      'https://example.com/watch?v=dQw4w9WgXcQ',
    ]) {
      test('rejects "$bad"', () => expect(parseYoutubeId(bad), isNull));
    }
  });

  test('parseYoutubeStart', () {
    expect(parseYoutubeStart('https://youtu.be/dQw4w9WgXcQ?t=90'), 90);
    expect(parseYoutubeStart('https://youtube.com/watch?v=dQw4w9WgXcQ&t=1m30s'), 90);
    expect(parseYoutubeStart('https://youtube.com/watch?v=dQw4w9WgXcQ&t=1h2m3s'), 3723);
    expect(parseYoutubeStart('https://youtube.com/watch?v=dQw4w9WgXcQ'), isNull);
  });

  test('video time formatting round-trips', () {
    expect(formatVideoTime(0), '0:00');
    expect(formatVideoTime(75), '1:15');
    expect(formatVideoTime(3725), '1:02:05');
    for (final s in [0, 59, 60, 754, 3599, 3600, 3725, 40000]) {
      expect(parseVideoTime(formatVideoTime(s)), s);
    }
    expect(parseVideoTime('12m34s'), 754);
    expect(parseVideoTime('754'), 754);
    expect(parseVideoTime('1:75'), isNull);
    expect(parseVideoTime('abc'), isNull);
  });

  test('synced video maps wall-clock moments to video seconds', () {
    final start = DateTime(2026, 11, 17, 19, 0, 0);
    final v1 = VideoLink(id: 'a', url: '', videoId: 'x', anchorMs: start.millisecondsSinceEpoch);
    final v2 = VideoLink(
      id: 'b',
      url: '',
      videoId: 'y',
      anchorMs: start.add(const Duration(hours: 1)).millisecondsSinceEpoch,
    );
    final day = GameDay(id: 'd', date: start, videos: [v1, v2]);

    expect(v1.secondsAt(start.add(const Duration(minutes: 5))), 300);
    expect(v1.secondsAt(start.subtract(const Duration(seconds: 1))), isNull);
    // Part 2 of the recording covers the later moments.
    expect(day.videoFor(start.add(const Duration(minutes: 10)))?.id, 'a');
    expect(day.videoFor(start.add(const Duration(minutes: 70)))?.id, 'b');
    expect(day.videoFor(start.subtract(const Duration(minutes: 1))), isNull);
  });
}
