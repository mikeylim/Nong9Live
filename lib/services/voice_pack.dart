import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// Pre-recorded announcer clips bundled in assets/voice/ (generated once by
/// tool/generate_voice.py). Missing clips fall back to the phone's TTS.
class VoicePack {
  VoicePack({this.lines = const {}, this.players = const {}, this.credit});

  /// key ("three", "block", "win_black", ...) -> clip file names.
  final Map<String, List<String>> lines;

  /// normalized full player name -> key -> clip file names.
  final Map<String, Map<String, List<String>>> players;
  final String? credit;

  bool get isEmpty => lines.isEmpty;

  static Future<VoicePack> load() async {
    try {
      final raw = await rootBundle.loadString('assets/voice/manifest.json');
      return VoicePack.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return VoicePack();
    }
  }

  factory VoicePack.fromJson(Map<String, dynamic> j) {
    List<String> files(dynamic v) => ((v as List?) ?? const []).cast<String>();
    return VoicePack(
      lines: {
        for (final e in ((j['lines'] as Map?) ?? const {}).entries) e.key as String: files(e.value),
      },
      players: {
        for (final p in ((j['players'] as Map?) ?? const {}).entries)
          p.key as String: {
            for (final e in (p.value as Map).entries) e.key as String: files(e.value),
          },
      },
      credit: j['credit'] as String?,
    );
  }

  static String normName(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  bool hasPlayer(String name) => players.containsKey(normName(name));

  /// Asset path (relative to assets/) of a clip for the first key that has
  /// one. With [playerName], that player's own clips win over generic ones.
  String? clipFor(List<String> keys, Random rng, {String? playerName}) {
    for (final k in keys) {
      if (playerName != null) {
        final own = players[normName(playerName)]?[k];
        if (own != null && own.isNotEmpty) return 'voice/${own[rng.nextInt(own.length)]}';
      }
      final generic = lines[k];
      if (generic != null && generic.isNotEmpty) return 'voice/${generic[rng.nextInt(generic.length)]}';
    }
    return null;
  }
}
