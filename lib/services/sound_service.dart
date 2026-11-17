import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'announcer.dart';
import 'voice_pack.dart';

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

  /// Recorded announcer clips; empty until [init] loads the manifest.
  VoicePack voice = VoicePack();
  Future<AudioPlayer>? _voicePlayer;
  final _rng = Random();

  /// How often a player's own clip ("Jay for three!") beats the generic one.
  static const personalCallChance = 0.65;

  Future<void> init() async {
    voice = await VoicePack.load();
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

  /// Phone text-to-speech (used for "say anything" and calls with no clip).
  Future<void> say(String text) async {
    final tts = _tts;
    if (tts == null || text.trim().isEmpty) return;
    try {
      await _stopVoice();
      await tts.stop();
      await tts.speak(text);
    } catch (e) {
      debugPrint('say: $e');
    }
  }

  /// Plays the recorded clip for [call], or reads its text if there is none.
  Future<void> announce(Call call) async {
    final personal = call.player != null &&
        voice.hasPlayer(call.player!.name) &&
        _rng.nextDouble() < personalCallChance;
    final clip = voice.clipFor(call.keys, _rng, playerName: personal ? call.player!.name : null);
    if (clip == null) return say(call.text);
    try {
      await _tts?.stop();
      final p = await (_voicePlayer ??= _createVoicePlayer());
      await p.stop();
      await p.play(AssetSource(clip));
    } catch (e) {
      debugPrint('announce $clip: $e');
      await say(call.text);
    }
  }

  Future<AudioPlayer> _createVoicePlayer() async {
    // One reusable player for the (longer) voice clips; effects use SoundPool.
    final p = AudioPlayer(playerId: 'announcer');
    p.onPlayerStateChanged.listen((_) {}, onError: (Object e) => debugPrint('announcer error: $e'));
    await p.setReleaseMode(ReleaseMode.stop);
    return p;
  }

  Future<void> _stopVoice() async {
    final f = _voicePlayer;
    if (f != null) await (await f).stop();
  }

  Future<void> stopAll() async {
    for (final f in _players.values) {
      try {
        await (await f).stop();
      } catch (_) {}
    }
    try {
      await _stopVoice();
      await _tts?.stop();
    } catch (_) {}
  }
}
