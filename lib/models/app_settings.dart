import 'package:flutter/material.dart';

import 'game.dart';

class AppSettings {
  AppSettings({
    this.crewName = 'Nong9 Live',
    this.metric = true,
    this.sfx = true,
    this.announcer = true,
    this.askAssist = true,
    this.askRebound = true,
    this.keepScreenOn = true,
    this.themeMode = ThemeMode.system,
    GameRules? defaultRules,
    this.lastLocation,
    this.minGamesForLeaders = 3,
  }) : defaultRules = defaultRules ?? GameRules(targetScore: 21);

  String crewName;

  /// cm/kg when true, ft-in/lb when false.
  bool metric;

  /// Sound effects while scoring (whistle on fouls, swish on buckets...).
  bool sfx;

  /// Text-to-speech announcer for big plays ("Mike for three!").
  bool announcer;

  /// After a made shot, ask who assisted.
  bool askAssist;

  /// After a missed shot, ask who got the rebound.
  bool askRebound;
  bool keepScreenOn;
  ThemeMode themeMode;
  GameRules defaultRules;
  String? lastLocation;
  int minGamesForLeaders;

  Map<String, dynamic> toJson() => {
        'crewName': crewName,
        'metric': metric,
        'sfx': sfx,
        'announcer': announcer,
        'askAssist': askAssist,
        'askRebound': askRebound,
        'keepScreenOn': keepScreenOn,
        'themeMode': themeMode.name,
        'defaultRules': defaultRules.toJson(),
        'lastLocation': lastLocation,
        'minGamesForLeaders': minGamesForLeaders,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        crewName: j['crewName'] as String? ?? 'Nong9 Live',
        metric: j['metric'] as bool? ?? true,
        sfx: j['sfx'] as bool? ?? true,
        announcer: j['announcer'] as bool? ?? true,
        askAssist: j['askAssist'] as bool? ?? true,
        askRebound: j['askRebound'] as bool? ?? true,
        keepScreenOn: j['keepScreenOn'] as bool? ?? true,
        themeMode: ThemeMode.values.where((m) => m.name == j['themeMode']).firstOrNull ?? ThemeMode.system,
        defaultRules: j['defaultRules'] is Map
            ? GameRules.fromJson((j['defaultRules'] as Map).cast<String, dynamic>())
            : null,
        lastLocation: j['lastLocation'] as String?,
        minGamesForLeaders: (j['minGamesForLeaders'] as num?)?.toInt() ?? 3,
      );
}
