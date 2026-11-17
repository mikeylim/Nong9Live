import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';

import '../models/app_settings.dart';
import '../models/game.dart';
import '../models/game_day.dart';
import '../models/game_event.dart';
import '../models/player.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Single source of truth. Everything lives in memory (a pickup group's
/// history is small) and every change is written through to Hive as JSON.
class AppStore extends ChangeNotifier {
  AppStore._(this._playersBox, this._daysBox, this._gamesBox, this._eventsBox, this._metaBox);

  static const backupFormat = 'nong9live-backup';
  static const backupVersion = 1;

  final Box<String> _playersBox;
  final Box<String> _daysBox;
  final Box<String> _gamesBox;
  final Box<String> _eventsBox;
  final Box<String> _metaBox;

  final Map<String, Player> _players = {};
  final Map<String, GameDay> _days = {};
  final Map<String, Game> _games = {};
  final Map<String, List<GameEvent>> _events = {};
  AppSettings settings = AppSettings();

  int _revision = 0;

  /// Bumped on every change; lets derived data (stats) cache safely.
  int get revision => _revision;

  /// Call after `Hive.initFlutter()`. [inMemory] keeps nothing on disk (tests).
  static Future<AppStore> open({bool inMemory = false}) async {
    Future<Box<String>> box(String name) =>
        Hive.openBox<String>(name, bytes: inMemory ? Uint8List(0) : null);
    final store = AppStore._(
      await box('players'),
      await box('gameDays'),
      await box('games'),
      await box('events'),
      await box('meta'),
    );
    store._load();
    return store;
  }

  void _load() {
    Map<String, dynamic> dec(String s) => (jsonDecode(s) as Map).cast<String, dynamic>();
    for (final s in _playersBox.values) {
      final p = Player.fromJson(dec(s));
      _players[p.id] = p;
    }
    for (final s in _daysBox.values) {
      final d = GameDay.fromJson(dec(s));
      _days[d.id] = d;
    }
    for (final s in _gamesBox.values) {
      final g = Game.fromJson(dec(s));
      _games[g.id] = g;
    }
    for (final s in _eventsBox.values) {
      final e = GameEvent.fromJson(dec(s));
      (_events[e.gameId] ??= []).add(e);
    }
    for (final list in _events.values) {
      list.sort((a, b) => a.at.compareTo(b.at));
    }
    final rawSettings = _metaBox.get('settings');
    if (rawSettings != null) settings = AppSettings.fromJson(dec(rawSettings));
  }

  void _changed() {
    _revision++;
    notifyListeners();
  }

  void _put(Box<String> box, String id, Map<String, dynamic> json) {
    unawaited(box.put(id, jsonEncode(json)));
  }

  // ------------------------------------------------------------- settings

  void saveSettings() {
    _put(_metaBox, 'settings', settings.toJson());
    _changed();
  }

  // -------------------------------------------------------------- players

  /// Active players sorted by name.
  List<Player> get players => allPlayers.where((p) => !p.archived).toList();

  List<Player> get allPlayers =>
      _players.values.toList()..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  Player? player(String? id) => id == null ? null : _players[id];

  void savePlayer(Player p) {
    _players[p.id] = p;
    _put(_playersBox, p.id, p.toJson());
    _changed();
  }

  /// Whether a player appears in any game (then we archive instead of delete
  /// so box scores keep their names).
  bool playerHasGames(String id) => _games.values.any((g) => g.allPlayerIds.contains(id));

  void deletePlayer(String id) {
    if (playerHasGames(id)) {
      final p = _players[id];
      if (p == null) return;
      p.archived = true;
      savePlayer(p);
      return;
    }
    _players.remove(id);
    unawaited(_playersBox.delete(id));
    for (final d in _days.values) {
      if (d.attendeeIds.remove(id)) _put(_daysBox, d.id, d.toJson());
    }
    _changed();
  }

  // ------------------------------------------------------------ game days

  /// Most recent first.
  List<GameDay> get gameDays => _days.values.toList()
    ..sort((a, b) {
      final c = b.date.compareTo(a.date);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });

  GameDay? gameDay(String? id) => id == null ? null : _days[id];

  GameDay? gameDayOn(DateTime date) {
    final d = dateOnly(date);
    for (final day in gameDays) {
      if (dateOnly(day.date) == d) return day;
    }
    return null;
  }

  GameDay createGameDay({required DateTime date, String? location, required List<String> attendeeIds}) {
    final day = GameDay(
      id: newId(),
      date: date,
      location: location?.trim().isEmpty == true ? null : location?.trim(),
      attendeeIds: attendeeIds,
    );
    if (day.location != null) {
      settings.lastLocation = day.location;
      _put(_metaBox, 'settings', settings.toJson());
    }
    saveGameDay(day);
    return day;
  }

  void saveGameDay(GameDay d) {
    _days[d.id] = d;
    _put(_daysBox, d.id, d.toJson());
    _changed();
  }

  void deleteGameDay(String id) {
    for (final g in gamesFor(id)) {
      _deleteGameData(g.id);
    }
    _days.remove(id);
    unawaited(_daysBox.delete(id));
    _changed();
  }

  // ---------------------------------------------------------------- games

  Game? game(String? id) => id == null ? null : _games[id];

  List<Game> gamesFor(String dayId) =>
      _games.values.where((g) => g.gameDayId == dayId).toList()..sort((a, b) => a.number.compareTo(b.number));

  List<Game> get allGames => _games.values.toList();

  /// The most recently started game that is still in progress.
  Game? get liveGame {
    final live = _games.values.where((g) => g.isLive).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return live.firstOrNull;
  }

  Game createGame({required String gameDayId, required List<TeamSide> teams, required GameRules rules}) {
    final existing = gamesFor(gameDayId);
    final number = existing.isEmpty ? 1 : existing.map((g) => g.number).reduce((a, b) => a > b ? a : b) + 1;
    final game = Game(
      id: newId(),
      gameDayId: gameDayId,
      number: number,
      teams: teams,
      rules: rules,
      startedAt: DateTime.now(),
      clockRemainingMs: rules.minutes == null ? null : rules.minutes! * 60000,
    );
    saveGame(game);
    return game;
  }

  void saveGame(Game g) {
    _games[g.id] = g;
    _put(_gamesBox, g.id, g.toJson());
    _changed();
  }

  void finishGame(Game g) {
    if (g.clockRunning) {
      g.clockRemainingMs = g.clockRemainingAt(DateTime.now());
      g.clockStartedAt = null;
    }
    g.status = GameStatus.finished;
    g.endedAt = DateTime.now();
    saveGame(g);
  }

  void reopenGame(Game g) {
    g.status = GameStatus.live;
    g.endedAt = null;
    saveGame(g);
  }

  void _deleteGameData(String gameId) {
    for (final e in _events.remove(gameId) ?? const <GameEvent>[]) {
      unawaited(_eventsBox.delete(e.id));
    }
    _games.remove(gameId);
    unawaited(_gamesBox.delete(gameId));
  }

  void deleteGame(String gameId) {
    _deleteGameData(gameId);
    _changed();
  }

  // --------------------------------------------------------------- events

  List<GameEvent> eventsFor(String gameId) => List.unmodifiable(_events[gameId] ?? const []);

  void addEvent(GameEvent e) {
    final list = _events[e.gameId] ??= [];
    list.add(e);
    if (list.length > 1 && list[list.length - 2].at.isAfter(e.at)) {
      list.sort((a, b) => a.at.compareTo(b.at));
    }
    _put(_eventsBox, e.id, e.toJson());
    _changed();
  }

  /// Removes an event plus anything linked to it (e.g. the assist on a shot).
  void removeEvent(GameEvent e) {
    final list = _events[e.gameId];
    if (list == null) return;
    final doomed = list.where((x) => x.id == e.id || x.linkedId == e.id).toList();
    for (final x in doomed) {
      list.remove(x);
      unawaited(_eventsBox.delete(x.id));
    }
    _changed();
  }

  /// Undo the latest primary event (and its linked assist/rebound).
  GameEvent? undoLast(String gameId) {
    final list = _events[gameId];
    if (list == null || list.isEmpty) return null;
    var target = list.last;
    if (target.linkedId != null) {
      target = list.firstWhere((x) => x.id == target.linkedId, orElse: () => target);
    }
    removeEvent(target);
    return target;
  }

  // --------------------------------------------------------------- backup

  Map<String, dynamic> toBackup() => {
        'format': backupFormat,
        'version': backupVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'settings': settings.toJson(),
        'players': _players.values.map((p) => p.toJson()).toList(),
        'gameDays': _days.values.map((d) => d.toJson()).toList(),
        'games': _games.values.map((g) => g.toJson()).toList(),
        'events': [for (final l in _events.values) ...l.map((e) => e.toJson())],
      };

  /// Replaces all data with a backup. Throws [FormatException] if invalid.
  Future<void> restoreBackup(Map<String, dynamic> json) async {
    if (json['format'] != backupFormat) {
      throw const FormatException('Not a Nong9 Live backup file');
    }
    List<Map<String, dynamic>> list(String k) =>
        ((json[k] as List?) ?? []).map((e) => (e as Map).cast<String, dynamic>()).toList();
    // Parse everything first so a bad file can't leave us half-restored.
    final players = list('players').map(Player.fromJson).toList();
    final days = list('gameDays').map(GameDay.fromJson).toList();
    final games = list('games').map(Game.fromJson).toList();
    final events = list('events').map(GameEvent.fromJson).toList();
    final newSettings =
        json['settings'] is Map ? AppSettings.fromJson((json['settings'] as Map).cast<String, dynamic>()) : settings;

    await clearAll(notify: false);
    for (final p in players) {
      _players[p.id] = p;
    }
    for (final d in days) {
      _days[d.id] = d;
    }
    for (final g in games) {
      _games[g.id] = g;
    }
    for (final e in events) {
      (_events[e.gameId] ??= []).add(e);
    }
    for (final l in _events.values) {
      l.sort((a, b) => a.at.compareTo(b.at));
    }
    settings = newSettings;
    String enc(Map<String, dynamic> m) => jsonEncode(m);
    await _playersBox.putAll({for (final p in players) p.id: enc(p.toJson())});
    await _daysBox.putAll({for (final d in days) d.id: enc(d.toJson())});
    await _gamesBox.putAll({for (final g in games) g.id: enc(g.toJson())});
    await _eventsBox.putAll({for (final e in events) e.id: enc(e.toJson())});
    await _metaBox.put('settings', enc(settings.toJson()));
    _changed();
  }

  Future<void> clearAll({bool notify = true}) async {
    _players.clear();
    _days.clear();
    _games.clear();
    _events.clear();
    await Future.wait([
      _playersBox.clear(),
      _daysBox.clear(),
      _gamesBox.clear(),
      _eventsBox.clear(),
    ]);
    if (notify) _changed();
  }
}
