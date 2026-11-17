import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:nong9live/models/game.dart';
import 'package:nong9live/models/game_event.dart';
import 'package:nong9live/models/player.dart';
import 'package:nong9live/services/announcer.dart';
import 'package:nong9live/services/voice_pack.dart';

/// Every clip key the app can ask for (live scorer, ref pads, quick phrases).
const usedKeys = [
  'three', 'deep', 'bucket', 'airball', 'block', 'steal', 'foul', 'tipoff', 'gamepoint', 'gameover', //
  'ft', 'brick', 'travel', 'timeout', 'hype', //
  'and_one', 'ball_dont_lie', 'check_ball', 'next', 'run_it_back', 'whos_next', 'defense', 'ice_cold',
];

GameEvent ev(EventType t, {bool airball = false}) =>
    GameEvent(id: 'e', gameId: 'g', team: 0, type: t, at: DateTime(2026), airball: airball);

void main() {
  group('bundled voice pack', () {
    final manifest = jsonDecode(File('assets/voice/manifest.json').readAsStringSync()) as Map<String, dynamic>;
    final pack = VoicePack.fromJson(manifest);

    test('has a clip for every key the app uses', () {
      for (final k in usedKeys) {
        expect(pack.lines[k], isNotEmpty, reason: 'missing clip key "$k"');
      }
      for (final (color, _) in teamColorPresets) {
        expect(pack.lines['win_${color.toLowerCase()}'], isNotEmpty, reason: color);
        expect(pack.lines['gamepoint_${color.toLowerCase()}'], isNotEmpty, reason: color);
      }
    });

    test('every listed clip file exists', () {
      final all = [
        ...pack.lines.values.expand((f) => f),
        ...pack.players.values.expand((m) => m.values.expand((f) => f)),
      ];
      expect(all, isNotEmpty);
      for (final f in all) {
        expect(File('assets/voice/$f').existsSync(), isTrue, reason: f);
      }
    });
  });

  group('clip selection', () {
    final pack = VoicePack.fromJson({
      'lines': {
        'three': ['three_1.mp3', 'three_2.mp3'],
        'gameover': ['gameover_1.mp3'],
      },
      'players': {
        'jay park': {
          'three': ['p_jay_park_three_1.mp3'],
        },
      },
    });

    test('falls through keys in order', () {
      expect(pack.clipFor(['win_black', 'gameover'], Random(1)), 'voice/gameover_1.mp3');
      expect(pack.clipFor(['nope'], Random(1)), isNull);
      expect(VoicePack().clipFor(['three'], Random(1)), isNull);
    });

    test("a player's own clip wins, matched by normalized name", () {
      expect(pack.clipFor(['three'], Random(1), playerName: '  Jay   PARK '), 'voice/p_jay_park_three_1.mp3');
      expect(pack.hasPlayer('jay park'), isTrue);
      // No personal clip for this key or player -> generic.
      expect(pack.clipFor(['gameover'], Random(1), playerName: 'Jay Park'), 'voice/gameover_1.mp3');
      expect(pack.clipFor(['three'], Random(1), playerName: 'Danny')!.startsWith('voice/three_'), isTrue);
    });
  });

  group('announcer calls', () {
    final jay = Player(id: 'j', name: 'Jay Park', nickname: 'J-Splash');
    final std = GameRules();
    final street = GameRules(scoring: ScoringMode.streetball);

    test('big plays always get a call with the right keys', () {
      final a = Announcer(Random(1));
      expect(a.callFor(ev(EventType.outsideMade), jay, std)!.keys, ['three']);
      expect(a.callFor(ev(EventType.outsideMade), jay, street)!.keys, ['deep', 'three']);
      expect(a.callFor(ev(EventType.outsideMade), jay, std)!.text, 'J-Splash for three!');
      expect(a.callFor(ev(EventType.outsideMiss, airball: true), jay, std)!.keys, ['airball']);
      expect(a.callFor(ev(EventType.block), jay, std)!.keys, ['block']);
      expect(a.callFor(ev(EventType.steal), jay, std)!.player, jay);
      expect(a.callFor(ev(EventType.rebound), jay, std), isNull);
      expect(a.callFor(ev(EventType.ftMade), jay, std), isNull);
    });

    test('plain buckets are only called sometimes', () {
      final a = Announcer(Random(3));
      final calls = List.generate(400, (_) => a.callFor(ev(EventType.insideMade), jay, std)).whereType<Call>().length;
      expect(calls, inInclusiveRange(100, 180)); // ~35%
    });

    test('team color names map to color clips, custom names fall back', () {
      final a = Announcer(Random(1));
      final black = TeamSide(name: 'Black', colorValue: 0);
      final custom = TeamSide(name: 'Monstars', colorValue: 0);
      expect(a.gamePoint(black).keys, ['gamepoint_black', 'gamepoint']);
      expect(a.gamePoint(custom).keys, ['gamepoint']);
      final g = Game(id: 'g', gameDayId: 'd', number: 1, teams: [black, custom], rules: std);
      final over = a.gameOver(g, [21, 15]);
      expect(over.keys.last, 'gameover');
      expect(over.text, contains('Black'));
      expect(a.gameOver(g, [15, 21]).keys, ['gameover']);
      expect(a.gameOver(g, [10, 10]).text, contains('tie'));
    });
  });
}
