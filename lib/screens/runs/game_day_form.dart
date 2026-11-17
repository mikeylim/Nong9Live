import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/format.dart';
import '../../models/game_day.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'game_day_screen.dart';

/// Create a run (or edit an existing one): date, place, who showed up.
class GameDayFormScreen extends StatefulWidget {
  const GameDayFormScreen({super.key, this.existing});
  final GameDay? existing;

  @override
  State<GameDayFormScreen> createState() => _GameDayFormScreenState();
}

class _GameDayFormScreenState extends State<GameDayFormScreen> {
  late DateTime _date;
  late final TextEditingController _location;
  late Set<String> _present;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    final e = widget.existing;
    _date = e?.date ?? DateTime.now();
    _location = TextEditingController(text: e?.location ?? store.settings.lastLocation ?? '');
    // Fixed crew: everyone is checked in by default; untick who's missing.
    _present = e != null ? {...e.attendeeIds} : store.players.map((p) => p.id).toSet();
  }

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = DateTime(d.year, d.month, d.day, _date.hour, _date.minute));
  }

  Future<void> _addGuest() async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Add a guest'),
          content: TextField(
            controller: c,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Name'),
            onSubmitted: (v) => Navigator.pop(ctx, v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Add')),
          ],
        );
      },
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final store = context.read<AppStore>();
    final p = Player(
      id: newId(),
      name: name.trim(),
      colorValue: avatarColors[store.allPlayers.length % avatarColors.length].toARGB32(),
    );
    store.savePlayer(p);
    setState(() => _present.add(p.id));
  }

  void _save() {
    final store = context.read<AppStore>();
    final e = widget.existing;
    if (e != null) {
      e.date = _date;
      e.location = _location.text.trim().isEmpty ? null : _location.text.trim();
      e.attendeeIds = _present.toList();
      store.saveGameDay(e);
      Navigator.pop(context);
      return;
    }
    final day = store.createGameDay(date: _date, location: _location.text, attendeeIds: _present.toList());
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameDayScreen(dayId: day.id)));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final players = store.players;
    // Include archived players that were already part of this run.
    final extra = store.allPlayers.where((p) => p.archived && _present.contains(p.id));
    final all = [...players, ...extra];
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New run' : 'Edit run')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.calendar_month_rounded, color: AppColors.orange),
                  title: Text(formatDayLong(_date), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Date'),
                  trailing: const Icon(Icons.edit_calendar_rounded),
                  onTap: _pickDate,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: TextField(
                    controller: _location,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.place_rounded),
                      hintText: 'Where? (e.g. Community Center Gym)',
                    ),
                  ),
                ),
              ],
            ),
          ),
          SectionHeader(
            "Who's here · ${_present.length}",
            padding: const EdgeInsets.fromLTRB(4, 20, 0, 6),
            trailing: TextButton(
              onPressed: () => setState(() {
                if (_present.length == all.length) {
                  _present.clear();
                } else {
                  _present = all.map((p) => p.id).toSet();
                }
              }),
              child: Text(_present.length == all.length ? 'Clear' : 'Everyone'),
            ),
          ),
          if (all.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No players yet. Add guests below or set up your roster in the Players tab.',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final p in all)
                  CheckboxListTile(
                    value: _present.contains(p.id),
                    onChanged: (v) => setState(() => v == true ? _present.add(p.id) : _present.remove(p.id)),
                    secondary: PlayerAvatar(player: p, size: 38),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      [if (p.jerseyNumber != null) '#${p.jerseyNumber}', if (p.positionLabel.isNotEmpty) p.positionLabel]
                          .join(' · '),
                    ),
                    activeColor: AppColors.orange,
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_add_alt_1_rounded)),
                  title: const Text('Add a guest', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Someone new showed up'),
                  onTap: _addGuest,
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: Icon(widget.existing == null ? Icons.sports_basketball_rounded : Icons.check_rounded),
            label: Text(widget.existing == null ? "Let's run (${_present.length} players)" : 'Save'),
            onPressed: _save,
          ),
        ),
      ),
    );
  }
}
