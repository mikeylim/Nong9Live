import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/backup_service.dart';
import '../../data/demo_data.dart';
import '../../models/game.dart';
import '../../services/announcer.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final cs = Theme.of(context).colorScheme;
    void save() => store.saveSettings();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        children: [
          const SectionHeader('Your crew', padding: EdgeInsets.fromLTRB(4, 8, 0, 8)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Text('🏀', style: TextStyle(fontSize: 24)),
                  title: Text(s.crewName, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Crew / app name'),
                  trailing: const Icon(Icons.edit_rounded),
                  onTap: () async {
                    final c = TextEditingController(text: s.crewName);
                    final v = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Crew name'),
                        content: TextField(controller: c, autofocus: true, textCapitalization: TextCapitalization.words),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
                        ],
                      ),
                    );
                    if (v != null && v.trim().isNotEmpty) {
                      s.crewName = v.trim();
                      save();
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.straighten_rounded),
                  title: const Text('Units', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: SegmentedButton<bool>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: true, label: Text('cm/kg')),
                      ButtonSegment(value: false, label: Text('ft/lb')),
                    ],
                    selected: {s.metric},
                    onSelectionChanged: (v) {
                      s.metric = v.first;
                      save();
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Theme', style: TextStyle(fontWeight: FontWeight.w600)),
                  trailing: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {s.themeMode},
                    onSelectionChanged: (v) {
                      s.themeMode = v.first;
                      save();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SectionHeader('Scorekeeping', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.volume_up_rounded),
                  title: const Text('Sound effects', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Swish, whistle, buzzer while scoring'),
                  value: s.sfx,
                  onChanged: (v) {
                    s.sfx = v;
                    save();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.record_voice_over_rounded),
                  title: const Text('Announcer voice', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Calls threes, blocks, airballs, game point & final'),
                  value: s.announcer,
                  onChanged: (v) {
                    s.announcer = v;
                    save();
                    if (v) context.read<SoundService>().announce(const Call(['tipoff'], 'Announcer is in the building!'));
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.handshake_outlined),
                  title: const Text('Ask for assists', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('After a made basket'),
                  value: s.askAssist,
                  onChanged: (v) {
                    s.askAssist = v;
                    save();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.sports_basketball_outlined),
                  title: const Text('Ask for rebounds', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('After a miss'),
                  value: s.askRebound,
                  onChanged: (v) {
                    s.askRebound = v;
                    save();
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.light_mode_outlined),
                  title: const Text('Keep screen on', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('During live games'),
                  value: s.keepScreenOn,
                  onChanged: (v) {
                    s.keepScreenOn = v;
                    save();
                  },
                ),
              ],
            ),
          ),
          const SectionHeader('Default rules', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ScoringMode>(
                      segments: const [
                        ButtonSegment(value: ScoringMode.standard, label: Text('2s & 3s')),
                        ButtonSegment(value: ScoringMode.streetball, label: Text('1s & 2s')),
                      ],
                      selected: {s.defaultRules.scoring},
                      onSelectionChanged: (v) {
                        s.defaultRules.scoring = v.first;
                        save();
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final v in <int?>[null, 11, 15, 21])
                        ChoiceChip(
                          label: Text(v == null ? 'No target' : 'To $v'),
                          selected: s.defaultRules.targetScore == v,
                          onSelected: (_) {
                            s.defaultRules.targetScore = v;
                            save();
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Each new game copies the previous game of the day, or these defaults for game 1.',
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                ],
              ),
            ),
          ),
          const SectionHeader('Leaderboards', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
          Card(
            child: ListTile(
              leading: const Icon(Icons.leaderboard_outlined),
              title: const Text('Minimum games for averages', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: s.minGamesForLeaders > 1
                        ? () {
                            s.minGamesForLeaders--;
                            save();
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('${s.minGamesForLeaders}', style: scoreStyle(22)),
                  IconButton(
                    onPressed: () {
                      s.minGamesForLeaders++;
                      save();
                    },
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SectionHeader('Data', padding: EdgeInsets.fromLTRB(4, 20, 0, 8)),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: const Text('Export backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Save everything (incl. photos) to Drive, email, chat...'),
                  onTap: () async {
                    try {
                      await BackupService.export(store);
                    } catch (e) {
                      if (context.mounted) toast(context, 'Export failed: $e');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Restore backup', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Replaces all data on this phone'),
                  onTap: () async {
                    try {
                      final json = await BackupService.pick();
                      if (json == null || !context.mounted) return;
                      final players = (json['players'] as List?)?.length ?? 0;
                      final games = (json['games'] as List?)?.length ?? 0;
                      final ok = await confirm(
                        context,
                        title: 'Restore backup?',
                        message: 'It has $players players and $games games. Everything currently in the app will be replaced.',
                        confirmLabel: 'Restore',
                        destructive: true,
                      );
                      if (!ok) return;
                      await BackupService.restore(store, json);
                      if (context.mounted) toast(context, 'Backup restored');
                    } catch (e) {
                      if (context.mounted) toast(context, 'Could not restore: $e');
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.science_outlined),
                  title: const Text('Load demo data', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('12 sample players + 5 weeks of games'),
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Load demo data?',
                      message: 'Sample players and games are added next to your own data.',
                      confirmLabel: 'Load',
                    );
                    if (ok) DemoData.seed(store);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_forever_rounded, color: AppColors.loss),
                  title: const Text('Erase all data', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.loss)),
                  onTap: () async {
                    final ok = await confirm(
                      context,
                      title: 'Erase everything?',
                      message: 'All players, runs, games and stats will be deleted. Export a backup first if unsure.',
                      confirmLabel: 'Erase',
                      destructive: true,
                    );
                    if (ok) await store.clearAll();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Nong9 Live · v1.2\nAnnouncer voice generated with ElevenLabs\n'
              'Sound effects synthesized in-app · Barlow font (SIL OFL)',
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
