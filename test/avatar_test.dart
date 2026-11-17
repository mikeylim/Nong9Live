import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nong9live/models/avatar.dart';
import 'package:nong9live/models/player.dart';
import 'package:nong9live/screens/players/avatar_editor_screen.dart';
import 'package:nong9live/widgets/avatar_painter.dart';
import 'package:nong9live/widgets/common.dart';

void main() {
  test('avatar JSON round-trips, alone and inside a player', () {
    final spec = AvatarSpec(
      skin: skinTones[3].toARGB32(),
      hair: HairStyle.afro,
      hairColor: hairColors[1].toARGB32(),
      face: Face.hype,
      beard: Beard.goatee,
      eyewear: Eyewear.goggles,
      headband: accessoryColors[2].toARGB32(),
      jersey: jerseyColors[4].toARGB32(),
    );
    expect(AvatarSpec.fromJson(spec.toJson()), spec);

    final p = Player(id: 'p', name: 'Jay', avatar: spec);
    expect(Player.fromJson(p.toJson()).avatar, spec);
    expect(Player(id: 'q', name: 'No Avatar').toJson().containsKey('avatar'), isFalse);
    expect(Player.fromJson(Player(id: 'q', name: 'No Avatar').toJson()).avatar, isNull);
  });

  test('copyWith can clear the headband', () {
    final s = AvatarSpec.random(Random(1)).copyWith(headband: () => 0xFFFFFFFF);
    expect(s.headband, 0xFFFFFFFF);
    expect(s.copyWith(headband: () => null).headband, isNull);
    expect(s.copyWith(face: Face.grin).headband, 0xFFFFFFFF);
  });

  test('unknown values from old/foreign data fall back safely', () {
    final s = AvatarSpec.fromJson({'hair': 'dreadlocks', 'face': 42});
    expect(s.hair, HairStyle.short);
    expect(s.face, Face.smile);
  });

  test('random avatars vary', () {
    final rng = Random(5);
    final hairs = {for (var i = 0; i < 60; i++) AvatarSpec.random(rng).hair};
    expect(hairs.length, greaterThan(5));
  });

  testWidgets('every option combination paints at every size', (tester) async {
    final specs = [
      for (final h in HairStyle.values)
        for (final f in Face.values)
          AvatarSpec(
            skin: skinTones[h.index % skinTones.length].toARGB32(),
            hair: h,
            hairColor: hairColors[f.index].toARGB32(),
            face: f,
            beard: Beard.values[(h.index + f.index) % Beard.values.length],
            eyewear: Eyewear.values[h.index % Eyewear.values.length],
            headband: f.index.isEven ? accessoryColors[h.index % accessoryColors.length].toARGB32() : null,
            jersey: jerseyColors[h.index].toARGB32(),
          ),
    ];
    await tester.pumpWidget(MaterialApp(
      home: SingleChildScrollView(
        child: Wrap(children: [
          for (final s in specs)
            for (final size in [22.0, 60.0, 160.0])
              AvatarView(spec: s, size: size, background: Colors.blue, number: 23),
        ]),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.byType(AvatarView), findsNWidgets(specs.length * 3));
  });

  testWidgets('PlayerAvatar prefers the avatar over initials', (tester) async {
    final withAvatar = Player(id: 'a', name: 'Jay Park', avatar: AvatarSpec.random(Random(2)));
    final plain = Player(id: 'b', name: 'Danny Kim');
    await tester.pumpWidget(MaterialApp(
      home: Row(children: [PlayerAvatar(player: withAvatar), PlayerAvatar(player: plain)]),
    ));
    expect(find.byType(AvatarView), findsOneWidget);
    expect(find.text('DK'), findsOneWidget);
    expect(find.text('JP'), findsNothing);
  });

  testWidgets('editor: pick a hair style and save', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    AvatarEditResult? result;
    final start = AvatarSpec.random(Random(9)).copyWith(hair: HairStyle.bald);
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await Navigator.push<AvatarEditResult>(
            context,
            MaterialPageRoute(builder: (_) => AvatarEditorScreen(initial: start, background: Colors.orange, number: 7)),
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Afro')); // scroll the hair row like a user would
    await tester.pumpAndSettle();
    await tester.tap(find.text('Afro'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save avatar'));
    await tester.pumpAndSettle();

    expect(result?.spec?.hair, HairStyle.afro);
    expect(result?.spec?.skin, start.skin); // other choices untouched
  });
}
