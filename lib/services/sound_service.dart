import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// All synthesized sound effects (see tool/generate_sounds.py).
enum Sfx {
  whistle('whistle'),
  whistleLong('whistle_long'),
  whistleDouble('whistle_double'),
  buzzer('buzzer'),
  timeout('timeout'),
  airhorn('airhorn'),
  swish('swish'),
  score1('score1'),
  score2('score2'),
  score3('score3'),
  airball('airball'),
  crowd('crowd'),
  brick('brick'),
  block('block'),
  steal('steal'),
  beep('beep'),
  tipoff('tipoff');

  const Sfx(this.file);
  final String file;
  String get asset => 'sounds/$file.wav';
}

/// Plays sound effects and speaks announcer lines. Failures are swallowed:
/// a missing speaker must never break scorekeeping.
class SoundService {
  /// One player per sound, created once. Holding the Future (not the player)
  /// means rapid taps can't race to create duplicates.
  final Map<Sfx, Future<AudioPlayer>> _players = {};
  FlutterTts? _tts;

  Future<void> init() async {
    try {
      // Mix with other audio, so a phone playing music at the court keeps going.
      await AudioPlayer.global.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
    } catch (e) {
      debugPrint('audio context: $e');
    }
    try {
      final tts = FlutterTts();
      await tts.setLanguage('en-US');
      await tts.setSpeechRate(0.52);
      await tts.setPitch(1.0);
      await tts.setVolume(1.0);
      _tts = tts;
    } catch (e) {
      debugPrint('tts: $e');
    }
  }

  Future<AudioPlayer> _player(Sfx s) => _players[s] ??= _create(s);

  Future<AudioPlayer> _create(Sfx s) async {
    final p = AudioPlayer(playerId: 'sfx_${s.name}');
    try {
      // Android SoundPool: built for short effects. Loads off the UI thread,
      // starts instantly and lets sounds overlap (MediaPlayer did neither).
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(s.asset));
      return p;
    } catch (_) {
      _players.remove(s);
      rethrow;
    }
  }

  /// Loads players ahead of time so the first tap has no delay.
  Future<void> preload(Iterable<Sfx> sounds) async {
    for (final s in sounds) {
      try {
        await _player(s);
      } catch (e) {
        debugPrint('preload ${s.name}: $e');
      }
    }
  }

  Future<void> play(Sfx s) async {
    try {
      final p = await _player(s);
      await p.stop();
      await p.resume();
    } catch (e) {
      debugPrint('play ${s.name}: $e');
    }
  }

  Future<void> say(String text) async {
    final tts = _tts;
    if (tts == null || text.trim().isEmpty) return;
    try {
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('say: $e');
    }
  }

  Future<void> stopAll() async {
    for (final f in _players.values) {
      try {
        await (await f).stop();
      } catch (_) {}
    }
    try {
      await _tts?.stop();
    } catch (_) {}
  }
}
