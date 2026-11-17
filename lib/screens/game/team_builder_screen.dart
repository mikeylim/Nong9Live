import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../logic/team_balancer.dart';
import '../../models/game.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'live_game_screen.dart';

/// Pick teams + rules for the next game, then tip off.
class TeamBuilderScreen extends StatefulWidget {
  const TeamBuilderScreen({super.key, required this.dayId, this.initialTeams, this.lockFirstTeam = false});
  final String dayId;
  final List<TeamSide>? initialTeams;

  /// "Winner stays": keep team 1 fixed and fill challengers from the bench.
  final bool lockFirstTeam;

  @override
  State<TeamBuilderScreen> createState() => _TeamBuilderScreenState();
}

class _TeamBuilderScreenState extends State<TeamBuilderScreen> {
  final _rng = Random();
  late List<TeamSide> _teams;
  late GameRules _rules;
  late int _size;
  final _locked = [false, false];
  bool _showEveryone = false;
  Game? _previous;

  AppStore get _store => context.read<AppStore>();

  @override
  void initState() {
    super.initState();
    final store = _store;
    final day = store.gameDay(widget.dayId)!;
    final games = store.gamesFor(widget.dayId);
    _previous = games.lastOrNull;
    if (widget.initialTeams != null) {
      _teams = widget.initialTeams!.map((t) => t.copy()).toList();
    } else if (_previous != null) {
      _teams = _previous!.teams.map((t) => TeamSide(name: t.name, colorValue: t.colorValue)).toList();
    } else {
      _teams = [
        TeamSide(name: teamColorPresets[1].$1, colorValue: teamColorPresets[1].$2.toARGB32()),
        TeamSide(name: teamColorPresets[0].$1, colorValue: teamColorPresets[0].$2.toARGB32()),
      ];
    }
    _rules = (_previous?.rules ?? store.settings.defaultRules).copy();
    final prevSize = _previous?.teams.map((t) => t.playerIds.length).fold<int>(0, max) ?? 0;
    _size = prevSize > 0 ? prevSize : (day.attendeeIds.length ~/ 2).clamp(1, 5);
    _locked[0] = widget.lockFirstTeam;
  }

  List<Player> get _pool {
    final store = _store;
    final day = store.gameDay(widget.dayId)!;
    final here = day.attendeeIds.map(store.player).whereType<Player>().toList();
    final assigned = _teams.expand((t) => t.playerIds).toSet();
    final ids = here.map((p) => p.id).toSet();
    final extra = store.players.where((p) => !ids.contains(p.id) && (_showEveryone || assigned.contains(p.id)));
    return [...here, ...extra];
  }

  int? _teamOf(String id) {
    for (var i = 0; i < 2; i++) {
      if (_teams[i].playerIds.contains(id)) return i;
    }
    return null;
  }

  /// How many games each player has already played today (fair rotation).
  Map<String, int> get _gamesToday {
    final m = <String, int>{};
    for (final g in _store.gamesFor(widget.dayId)) {
      for (final id in g.allPlayerIds) {
        m[id] = (m[id] ?? 0) + 1;
      }
    }
    return m;
  }

  /// Picks [count] players from [candidates], favoring who played least.
  List<Player> _prioritized(List<Player> candidates, int count) {
    final played = _gamesToday;
    final shuffled = [...candidates]..shuffle(_rng);
    shuffled.sort((a, b) => (played[a.id] ?? 0).compareTo(played[b.id] ?? 0));
    return shuffled.take(count).toList();
  }

  void _cycle(Player p) {
    final t = _teamOf(p.id);
    if (t != null && _locked[t]) {
      toast(context, '${_teams[t].name} is locked. Unlock it to make changes.');
      return;
    }
    setState(() {
      if (t != null) _teams[t].playerIds.remove(p.id);
      final next = t == null ? 0 : (t == 0 ? 1 : null);
      if (next != null && !_locked[next]) {
        _teams[next].playerIds.add(p.id);
      } else if (next == 0 && _locked[0] && !_locked[1]) {
        _teams[1].playerIds.add(p.id);
      }
    });
  }

  void _makeTeams({required bool balanced}) {
    final pool = _pool;
    setState(() {
      final lockedIdx = _locked[0] ? 0 : (_locked[1] ? 1 : null);
      if (lockedIdx != null) {
        // Fill the other side from the bench.
        final keep = _teams[lockedIdx].playerIds.toSet();
        final bench = pool.where((p) => !keep.contains(p.id)).toList();
        final size = keep.isEmpty ? _size : keep.length;
        final other = 1 - lockedIdx;
        List<Player> chosen;
        if (balanced) {
          final target = TeamBalancer.totalStrength(keep.map(_store.player).whereType<Player>());
          chosen = _closestSubset(_prioritized(bench, min(bench.length, size + 2)), size, target);
        } else {
          chosen = _prioritized(bench, size);
        }
        _teams[other].playerIds = chosen.map((p) => p.id).toList();
        return;
      }
      final chosen = _prioritized(pool, min(pool.length, _size * 2));
      final split = balanced ? TeamBalancer.balance(chosen, _rng) : TeamBalancer.random(chosen, _rng);
      _teams[0].playerIds = split[0];
      _teams[1].playerIds = split[1];
    });
  }

  /// Subset of [cands] of size [k] whose total strength is closest to [target].
  List<Player> _closestSubset(List<Player> cands, int k, double target) {
    if (cands.length <= k) return cands;
    List<Player>? best;
    var bestDiff = double.infinity;
    void search(int start, List<Player> acc) {
      if (acc.length == k) {
        final d = (TeamBalancer.totalStrength(acc) - target).abs() + _rng.nextDouble() * 0.2;
        if (d < bestDiff) {
          bestDiff = d;
          best = [...acc];
        }
        return;
      }
      for (var i = start; i <= cands.length - (k - acc.length); i++) {
        acc.add(cands[i]);
        search(i + 1, acc);
        acc.removeLast();
      }
    }

    search(0, []);
    return best ?? cands.take(k).toList();
  }

  Future<void> _editTeam(int i) async {
    final picked = await pickTeamColor(context, current: _teams[i].color);
    if (picked == null) return;
    setState(() {
      final wasPreset = teamColorPresets.any((c) => c.$1 == _teams[i].name);
      _teams[i].colorValue = picked.$2.toARGB32();
      if (wasPreset || _teams[i].name.isEmpty) _teams[i].name = picked.$1;
    });
  }

  Future<void> _renameTeam(int i) async {
    final c = TextEditingController(text: _teams[i].name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Team name'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) setState(() => _teams[i].name = name.trim());
  }

  void _start() {
    final store = _store;
    final game = store.createGame(
      gameDayId: widget.dayId,
      teams: _teams.map((t) => t.copy()).toList(),
      rules: _rules.copy(),
    );
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LiveGameScreen(gameId: game.id, justStarted: true)),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<AppStore>();
    final pool = _pool;
    final played = _gamesToday;
    final cs = Theme.of(context).colorScheme;
    final nextNumber = (_store.gamesFor(widget.dayId).map((g) => g.number).fold<int>(0, max)) + 1;
    final bench = pool.where((p) => _teamOf(p.id) == null).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Game $nextNumber · Teams')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
        children: [
          Row(
            children: [
              for (var i = 0; i < 2; i++) ...[
                if (i == 1) const SizedBox(width: 10),
                Expanded(child: _teamHeader(i)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Players per team', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: _size > 1 ? () => setState(() => _size--) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(width: 44, child: Center(child: Text('$_size', style: scoreStyle(26)))),
              IconButton.filledTonal(
                onPressed: _size < 12 ? () => setState(() => _size++) : null,
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilledButton.tonalIcon(
                  icon: const Text('⚖️'),
                  label: const Text('Balance'),
                  onPressed: () => _makeTeams(balanced: true),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Text('🎲'),
                  label: const Text('Random'),
                  onPressed: () => _makeTeams(balanced: false),
                ),
                if (_previous != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Same as last'),
                    onPressed: () => setState(() {
                      _teams = _previous!.teams.map((t) => t.copy()).toList();
                      _locked[0] = _locked[1] = false;
                    }),
                  ),
                ],
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.clear_all_rounded),
                  label: const Text('Clear'),
                  onPressed: () => setState(() {
                    for (var i = 0; i < 2; i++) {
                      if (!_locked[i]) _teams[i].playerIds.clear();
                    }
                  }),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              'Tap a player to move them: bench → ${_teams[0].name} → ${_teams[1].name}. '
              'Balance uses player ratings; whoever has played the fewest games today gets in first.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final p in pool) _playerRow(p, played[p.id] ?? 0),
                SwitchListTile(
                  value: _showEveryone,
                  onChanged: (v) => setState(() => _showEveryone = v),
                  title: const Text('Show whole roster', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Include players not checked in today'),
                ),
              ],
            ),
          ),
          if (bench.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
              child: Text(
                'Sitting out: ${bench.map((p) => p.displayName).join(', ')}',
                style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w600),
              ),
            ),
          const SectionHeader('Rules', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
          _RulesEditor(rules: _rules, onChanged: () => setState(() {})),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.sports_rounded),
            label: Text(
              _teams.every((t) => t.playerIds.isEmpty)
                  ? 'Tip off (team score only)'
                  : 'Tip off · ${_teams[0].playerIds.length} vs ${_teams[1].playerIds.length}',
            ),
            onPressed: _start,
          ),
        ),
      ),
    );
  }

  Widget _teamHeader(int i) {
    final t = _teams[i];
    final cs = Theme.of(context).colorScheme;
    final players = t.playerIds.map(_store.player).whereType<Player>().toList();
    final avg = players.isEmpty ? 0 : players.map((p) => p.overall).reduce((a, b) => a + b) / players.length;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _editTeam(i),
            child: Container(
              height: 46,
              color: t.color,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Icon(Icons.palette_rounded, size: 18, color: t.onColor.withValues(alpha: 0.8)),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: _locked[i] ? 'Unlock team' : 'Lock team (winner stays)',
                    icon: Icon(_locked[i] ? Icons.lock_rounded : Icons.lock_open_rounded, color: t.onColor, size: 20),
                    onPressed: () => setState(() {
                      _locked[i] = !_locked[i];
                      if (_locked[i]) _locked[1 - i] = false;
                    }),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => _renameTeam(i),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge),
                      ),
                      Icon(Icons.edit_rounded, size: 14, color: cs.onSurfaceVariant),
                    ],
                  ),
                  Text(
                    '${players.length} players${players.isEmpty ? '' : ' · avg ${avg.round()}'}',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _playerRow(Player p, int gamesToday) {
    final t = _teamOf(p.id);
    final cs = Theme.of(context).colorScheme;
    Widget dot(int i) {
      final selected = t == i;
      final team = _teams[i];
      return GestureDetector(
        onTap: () => setState(() {
          if (_locked[i] && !selected) return;
          final cur = _teamOf(p.id);
          if (cur != null && _locked[cur]) return;
          if (cur != null) _teams[cur].playerIds.remove(p.id);
          if (!selected) team.playerIds.add(p.id);
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          margin: const EdgeInsets.only(left: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? team.color : Colors.transparent,
            border: Border.all(color: selected ? AppColors.orange : cs.outline, width: selected ? 2.5 : 1.2),
          ),
          alignment: Alignment.center,
          child: Text(
            team.name.characters.first.toUpperCase(),
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: selected ? team.onColor : cs.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return InkWell(
      onTap: () => _cycle(p),
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(width: 5, color: t == null ? Colors.transparent : visibleTeamColorIn(context, _teams[t].color)),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
        child: Row(
          children: [
            PlayerAvatar(player: p, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
                  Row(
                    children: [
                      if (p.positionLabel.isNotEmpty) ...[
                        Text(p.positionLabel, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                      ],
                      Text('OVR ${p.overall}', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                      if (gamesToday > 0) ...[
                        const SizedBox(width: 8),
                        Text('· played $gamesToday', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12.5)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            dot(0),
            dot(1),
          ],
        ),
      ),
    );
  }
}

class _RulesEditor extends StatelessWidget {
  const _RulesEditor({required this.rules, required this.onChanged});
  final GameRules rules;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget label(String s) => Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 14),
          child: Text(s, style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
        );
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label('Scoring'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ScoringMode>(
                segments: const [
                  ButtonSegment(value: ScoringMode.standard, label: Text('2s & 3s')),
                  ButtonSegment(value: ScoringMode.streetball, label: Text('1s & 2s')),
                ],
                selected: {rules.scoring},
                onSelectionChanged: (s) {
                  rules.scoring = s.first;
                  onChanged();
                },
              ),
            ),
            label('Game to'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in <int?>[null, 11, 15, 21, 32])
                  ChoiceChip(
                    label: Text(v == null ? 'No limit' : '$v'),
                    selected: rules.targetScore == v,
                    onSelected: (_) {
                      rules.targetScore = v;
                      onChanged();
                    },
                  ),
                ActionChip(
                  label: Text(
                    rules.targetScore != null && ![11, 15, 21, 32].contains(rules.targetScore)
                        ? '${rules.targetScore} ✎'
                        : 'Custom',
                  ),
                  onPressed: () async {
                    final v = await _askNumber(context, 'Play to how many points?', rules.targetScore ?? 21);
                    if (v != null && v > 0) {
                      rules.targetScore = v;
                      onChanged();
                    }
                  },
                ),
              ],
            ),
            if (rules.targetScore != null)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: rules.winByTwo,
                onChanged: (v) {
                  rules.winByTwo = v;
                  onChanged();
                },
                title: const Text('Win by 2', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            label('Game clock'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in <int?>[null, 8, 10, 12, 15, 20])
                  ChoiceChip(
                    label: Text(v == null ? 'Off' : '$v min'),
                    selected: rules.minutes == v,
                    onSelected: (_) {
                      rules.minutes = v;
                      onChanged();
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<int?> _askNumber(BuildContext context, String title, int initial) {
    final c = TextEditingController(text: '$initial');
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, autofocus: true, keyboardType: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, int.tryParse(c.text)), child: const Text('OK')),
        ],
      ),
    );
  }
}
