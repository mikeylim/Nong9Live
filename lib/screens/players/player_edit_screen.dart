import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../data/photo_store.dart';
import '../../logic/format.dart';
import '../../models/player.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'avatar_editor_screen.dart';

class PlayerEditScreen extends StatefulWidget {
  const PlayerEditScreen({super.key, this.existing});
  final Player? existing;

  @override
  State<PlayerEditScreen> createState() => _PlayerEditScreenState();
}

class _PlayerEditScreenState extends State<PlayerEditScreen> {
  late final Player _p;
  late final TextEditingController _name, _nick, _number, _bio, _h1, _h2, _w;
  late final bool _metric;
  String? _originalPhoto;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _metric = store.settings.metric;
    _p = widget.existing?.copy() ??
        Player(
          id: newId(),
          name: '',
          colorValue: avatarColors[store.allPlayers.length % avatarColors.length].toARGB32(),
        );
    _originalPhoto = _p.photoPath;
    _name = TextEditingController(text: _p.name);
    _nick = TextEditingController(text: _p.nickname ?? '');
    _number = TextEditingController(text: _p.jerseyNumber?.toString() ?? '');
    _bio = TextEditingController(text: _p.bio ?? '');
    if (_metric) {
      _h1 = TextEditingController(text: _p.heightCm?.round().toString() ?? '');
      _h2 = TextEditingController();
      _w = TextEditingController(text: _p.weightKg?.round().toString() ?? '');
    } else {
      final totalIn = _p.heightCm == null ? null : (_p.heightCm! / 2.54).round();
      _h1 = TextEditingController(text: totalIn == null ? '' : '${totalIn ~/ 12}');
      _h2 = TextEditingController(text: totalIn == null ? '' : '${totalIn % 12}');
      _w = TextEditingController(text: _p.weightKg == null ? '' : kgToLb(_p.weightKg!).round().toString());
    }
  }

  @override
  void dispose() {
    // A photo picked but never saved is an orphan file.
    if (!_saved && _p.photoPath != _originalPhoto) PhotoStore.delete(_p.photoPath);
    for (final c in [_name, _nick, _number, _bio, _h1, _h2, _w]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _photo() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.photo_camera_rounded), title: const Text('Take a photo'), onTap: () => Navigator.pop(ctx, 'camera')),
            ListTile(leading: const Icon(Icons.photo_library_rounded), title: const Text('Choose from gallery'), onTap: () => Navigator.pop(ctx, 'gallery')),
            if (_p.photoPath != null)
              ListTile(leading: const Icon(Icons.delete_outline_rounded), title: const Text('Remove photo'), onTap: () => Navigator.pop(ctx, 'remove')),
          ],
        ),
      ),
    );
    if (choice == null) return;
    if (choice == 'remove') {
      if (_p.photoPath != _originalPhoto) await PhotoStore.delete(_p.photoPath);
      setState(() => _p.photoPath = null);
      return;
    }
    try {
      final name = await PhotoStore.pick(choice == 'camera' ? ImageSource.camera : ImageSource.gallery, _p.id);
      if (name == null) return;
      if (_p.photoPath != _originalPhoto) await PhotoStore.delete(_p.photoPath);
      setState(() => _p.photoPath = name);
    } catch (e) {
      if (mounted) toast(context, 'Could not get photo: $e');
    }
  }

  Future<void> _editAvatar() async {
    final result = await Navigator.push<AvatarEditResult>(
      context,
      MaterialPageRoute(
        builder: (_) => AvatarEditorScreen(
          initial: _p.avatar,
          background: _p.color,
          number: int.tryParse(_number.text.trim()),
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _p.avatar = result.spec);
    if (result.spec != null && _p.photoPath != null) {
      toast(context, 'The photo shows first. Remove it (tap the picture) to use the avatar.');
    }
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      toast(context, 'Give them a name');
      return;
    }
    _p.name = name;
    _p.nickname = _nick.text.trim().isEmpty ? null : _nick.text.trim();
    _p.jerseyNumber = int.tryParse(_number.text.trim());
    _p.bio = _bio.text.trim().isEmpty ? null : _bio.text.trim();
    if (_metric) {
      _p.heightCm = double.tryParse(_h1.text.trim());
      _p.weightKg = double.tryParse(_w.text.trim());
    } else {
      final ft = int.tryParse(_h1.text.trim());
      final inch = int.tryParse(_h2.text.trim()) ?? 0;
      _p.heightCm = ft == null ? null : feetInchesToCm(ft, inch);
      final lb = double.tryParse(_w.text.trim());
      _p.weightKg = lb == null ? null : lbToKg(lb);
    }
    if (_originalPhoto != null && _originalPhoto != _p.photoPath) PhotoStore.delete(_originalPhoto);
    _saved = true;
    context.read<AppStore>().savePlayer(_p);
    Navigator.pop(context);
  }

  Future<void> _addCustom(List<String> target) async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add your own'),
        content: TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Add')),
        ],
      ),
    );
    if (v != null && v.trim().isNotEmpty && !target.contains(v.trim())) setState(() => target.add(v.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New player' : 'Edit player'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 48),
        children: [
          Center(
            child: GestureDetector(
              onTap: _photo,
              child: Stack(
                children: [
                  PlayerAvatar(player: _p..name = _name.text.isEmpty ? '?' : _name.text, size: 108),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 3),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _photo,
                icon: const Icon(Icons.photo_camera_rounded, size: 20),
                label: Text(_p.photoPath == null ? 'Photo' : 'Change photo'),
              ),
              const SizedBox(width: 10),
              FilledButton.tonalIcon(
                onPressed: _editAvatar,
                icon: const Text('🧑🏽', style: TextStyle(fontSize: 18)),
                label: Text(_p.avatar == null ? 'Create avatar' : 'Edit avatar'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in avatarColors)
                  GestureDetector(
                    onTap: () => setState(() => _p.colorValue = c.toARGB32()),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _p.colorValue == c.toARGB32() ? cs.onSurface : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SectionHeader('Basics', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name *'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _nick,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Nickname'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _number,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                  decoration: const InputDecoration(labelText: 'Jersey #'),
                ),
              ),
            ],
          ),
          const SectionHeader('Position', padding: EdgeInsets.fromLTRB(4, 20, 0, 10)),
          Wrap(
            spacing: 8,
            children: [
              for (final pos in Position.values)
                FilterChip(
                  label: Text(pos.label),
                  selected: _p.positions.contains(pos),
                  onSelected: (v) => setState(() => v ? _p.positions.add(pos) : _p.positions.remove(pos)),
                ),
            ],
          ),
          const SectionHeader('Body', padding: EdgeInsets.fromLTRB(4, 20, 0, 10)),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _h1,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: _metric ? 'Height' : 'Feet', suffixText: _metric ? 'cm' : 'ft'),
                ),
              ),
              if (!_metric) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _h2,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Inches', suffixText: 'in'),
                  ),
                ),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _w,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Weight', suffixText: _metric ? 'kg' : 'lb'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('Shoots', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurfaceVariant)),
              const SizedBox(width: 12),
              Expanded(
                child: SegmentedButton<String>(
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 'R', label: Text('Right')),
                    ButtonSegment(value: 'L', label: Text('Left')),
                  ],
                  selected: {?_p.hand},
                  onSelectionChanged: (s) => setState(() => _p.hand = s.firstOrNull),
                ),
              ),
            ],
          ),
          SectionHeader(
            'Ratings',
            padding: const EdgeInsets.fromLTRB(4, 24, 0, 4),
            trailing: OvrBadge(overall: _p.overall),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              'Be honest. These power the player card and the "Balance teams" button.',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Column(
                children: [
                  for (final a in Attribute.values)
                    Row(
                      children: [
                        SizedBox(width: 96, child: Text(a.label, style: const TextStyle(fontWeight: FontWeight.w700))),
                        Expanded(
                          child: Slider(
                            value: (_p.ratings[a] ?? 5).toDouble(),
                            min: 1,
                            max: 10,
                            divisions: 9,
                            label: '${_p.ratings[a] ?? 5}',
                            onChanged: (v) => setState(() => _p.ratings[a] = v.round()),
                          ),
                        ),
                        SizedBox(width: 26, child: Text('${_p.ratings[a] ?? 5}', style: scoreStyle(20))),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SectionHeader('Strengths', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
          _TagPicker(selected: _p.strengths, color: AppColors.win, onChanged: () => setState(() {}), onCustom: () => _addCustom(_p.strengths)),
          const SectionHeader('Weaknesses', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
          _TagPicker(selected: _p.weaknesses, color: AppColors.foul, onChanged: () => setState(() {}), onCustom: () => _addCustom(_p.weaknesses)),
          const SectionHeader('About', padding: EdgeInsets.fromLTRB(4, 24, 0, 10)),
          TextField(
            controller: _bio,
            minLines: 2,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Signature move, favorite player, how they talk trash...'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save player')),
        ],
      ),
    );
  }
}

class _TagPicker extends StatelessWidget {
  const _TagPicker({required this.selected, required this.color, required this.onChanged, required this.onCustom});
  final List<String> selected;
  final Color color;
  final VoidCallback onChanged;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final custom = selected.where((s) => !strengthPresets.contains(s));
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in [...strengthPresets, ...custom])
          FilterChip(
            label: Text(s),
            selected: selected.contains(s),
            selectedColor: color.withValues(alpha: 0.25),
            side: BorderSide(color: selected.contains(s) ? color : Theme.of(context).colorScheme.outlineVariant),
            onSelected: (v) {
              v ? selected.add(s) : selected.remove(s);
              onChanged();
            },
          ),
        ActionChip(avatar: const Icon(Icons.add_rounded, size: 18), label: const Text('Custom'), onPressed: onCustom),
      ],
    );
  }
}
