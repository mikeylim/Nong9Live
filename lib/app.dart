import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'logic/stats.dart';
import 'screens/players/players_screen.dart';
import 'screens/ref/ref_screen.dart';
import 'screens/runs/runs_screen.dart';
import 'screens/stats/stats_screen.dart';
import 'services/announcer.dart';
import 'services/sound_service.dart';
import 'theme/app_theme.dart';

/// Which bottom tab is showing (lets screens jump to another tab).
class ShellController extends ValueNotifier<int> {
  ShellController() : super(0);
  static const runs = 0, players = 1, stats = 2, ref = 3;
}

class Nong9App extends StatelessWidget {
  const Nong9App({super.key, required this.store, required this.sound});
  final AppStore store;
  final SoundService sound;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        Provider.value(value: sound),
        Provider(create: (_) => StatsEngine(store)),
        Provider(create: (_) => Announcer()),
        ChangeNotifierProvider(create: (_) => ShellController()),
      ],
      child: Selector<AppStore, ThemeMode>(
        selector: (_, s) => s.settings.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'Nong9 Live',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: mode,
          home: const HomeShell(),
        ),
      ),
    );
  }
}

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    return Scaffold(
      body: IndexedStack(
        index: shell.value,
        children: const [RunsScreen(), PlayersScreen(), StatsScreen(), RefScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.value,
        onDestinationSelected: (i) {
          if (i == ShellController.ref) context.read<SoundService>().preload(Sfx.values);
          shell.value = i;
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.sports_basketball_outlined), selectedIcon: Icon(Icons.sports_basketball), label: 'Runs'),
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Players'),
          NavigationDestination(icon: Icon(Icons.leaderboard_outlined), selectedIcon: Icon(Icons.leaderboard), label: 'Stats'),
          NavigationDestination(icon: Icon(Icons.sports_outlined), selectedIcon: Icon(Icons.sports), label: 'Ref'),
        ],
      ),
    );
  }
}
