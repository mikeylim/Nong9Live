import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

import 'app.dart';
import 'data/app_store.dart';
import 'data/photo_store.dart';
import 'services/sound_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter('nong9live');
  await PhotoStore.init();
  final store = await AppStore.open();
  final sound = SoundService();
  unawaited(sound.init());
  runApp(Nong9App(store: store, sound: sound));
}
