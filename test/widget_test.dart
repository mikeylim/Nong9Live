import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nong9live/app.dart';
import 'package:nong9live/data/app_store.dart';
import 'package:nong9live/data/demo_data.dart';
import 'package:nong9live/logic/scoring.dart';
import 'package:nong9live/logic/stats.dart';
import 'package:nong9live/models/game.dart';
import 'package:nong9live/models/game_event.dart';
import 'package:nong9live/screens/game/live_game_screen.dart';
import 'package:nong9live/services/announcer.dart';
import 'package:nong9live/services/sound_service.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

/// No platform audio in tests; records what would have played.
class SilentSound extends SoundService {
  final played = <Sfx>[];
  final said = <String>[];
  @override
  Future<void> init() async {}
  @override
  Future<void> preload(Iterable<Sfx> sounds) async {}
  @override
  Future<void> play(Sfx s) async => played.add(s);
  @override
  Future<void> say(String text) async => said.add(text);
}

Future<void> settle(WidgetTester tester, [int frames = 6]) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  testWidgets('app shell renders every tab with demo data', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    late AppStore store;
    await tester.runAsync(() async => store = await freshStore());
    DemoData.seed(store, random: Random(1));
    await tester.pumpWidget(Nong9App(store: store, sound: SilentSound()));
    await settle(tester);

    expect(find.text('Nong9 Live'), findsOneWidget);
    expect(find.text('READY TO RUN?'), findsOneWidget);
    expect(find.text('HIGHLIGHTS'), findsOneWidget);

    await tester.tap(find.text('Players'));
    await settle(tester);
    expect(find.text('Players · 12'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await settle(tester);
    expect(find.text('Leaderboards'), findsOneWidget);
    expect(find.text('SINGLE-GAME RECORDS'), findsNothing); // below the fold is fine either way

    await tester.tap(find.text('Ref'));
    await settle(tester);
    expect(find.text('Ref mode'), findsOneWidget);
    expect(find.text('AIRBALL'), findsOneWidget);
  });

  testWidgets('live scoring: tap player, +3, skip assist, undo, end game', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    late AppStore store;
    await tester.runAsync(() async => store = await freshStore());
    store.settings.keepScreenOn = false;
    store.settings.announcer = true;
    final jay = addPlayer(store, 'Jay');
    final danny = addPlayer(store, 'Danny');
    final chris = addPlayer(store, 'Chris');
    final day = store.createGameDay(date: DateTime.now(), attendeeIds: [jay.id, danny.id, chris.id]);
    final game = store.createGame(
      gameDayId: day.id,
      teams: [
        TeamSide(name: 'Black', colorValue: 0xFF2B2B2B, playerIds: [jay.id, danny.id]),
        TeamSide(name: 'White', colorValue: 0xFFF1F1F1, playerIds: [chris.id]),
      ],
      rules: GameRules(targetScore: 21),
    );
    final sound = SilentSound();

    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        Provider<SoundService>.value(value: sound),
        Provider(create: (_) => StatsEngine(store)),
        Provider(create: (_) => Announcer(Random(0))),
      ],
      child: MaterialApp(home: LiveGameScreen(gameId: game.id)),
    ));
    await settle(tester);
    expect(find.text('BLACK'), findsOneWidget);

    // Tap Jay -> action pad -> +3.
    await tester.tap(find.text('Jay'));
    await settle(tester);
    expect(find.text('+3'), findsOneWidget);
    await tester.tap(find.text('+3'));
    await settle(tester);

    // Assist prompt lists Danny; skip it.
    expect(find.text('Assisted by?'), findsOneWidget);
    await tester.tap(find.text('No assist'));
    await settle(tester);

    var events = store.eventsFor(game.id);
    expect(events.single.type, EventType.outsideMade);
    expect(teamScores(events), [3, 0]);
    expect(sound.played, contains(Sfx.score3));
    expect(find.text('3'), findsWidgets);

    // Chris misses; rebound prompt -> Danny grabs it.
    await tester.tap(find.text('Chris'));
    await settle(tester);
    await tester.tap(find.text('MISS').first); // free-throw miss
    await settle(tester);
    expect(find.text('Rebound?'), findsOneWidget);
    await tester.tap(find.text('Danny').last);
    await settle(tester);
    events = store.eventsFor(game.id);
    expect(events.last.type, EventType.rebound);
    expect(events.last.playerId, danny.id);

    // Undo removes the miss and its linked rebound.
    await tester.tap(find.byTooltip('Undo last play'));
    await settle(tester);
    expect(store.eventsFor(game.id), hasLength(1));

    // End the game -> summary screen.
    await tester.tap(find.text('End'));
    await settle(tester);
    await tester.tap(find.text('End game'));
    await settle(tester, 20);
    expect(store.game(game.id)!.isFinished, isTrue);
    expect(sound.played, contains(Sfx.buzzer));
    expect(find.text('GAME MVP'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await settle(tester, 20);
  });
}
