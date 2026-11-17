import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/avatar.dart';
import '../../theme/app_theme.dart';
import '../../widgets/avatar_painter.dart';
import '../../widgets/common.dart';

/// Returned by [AvatarEditorScreen]: a new avatar, or `spec == null` to remove it.
class AvatarEditResult {
  const AvatarEditResult(this.spec);
  final AvatarSpec? spec;
}

class AvatarEditorScreen extends StatefulWidget {
  const AvatarEditorScreen({super.key, this.initial, required this.background, this.number});
  final AvatarSpec? initial;
  final Color background;
  final int? number;

  @override
  State<AvatarEditorScreen> createState() => _AvatarEditorScreenState();
}

class _AvatarEditorScreenState extends State<AvatarEditorScreen> {
  late AvatarSpec _spec = widget.initial ?? AvatarSpec.random();

  void _set(AvatarSpec s) {
    HapticFeedback.selectionClick();
    setState(() => _spec = s);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create avatar'),
        actions: [
          IconButton(
            tooltip: 'Randomize',
            icon: const Text('🎲', style: TextStyle(fontSize: 22)),
            onPressed: () => _set(AvatarSpec.random()),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surfaceContainerHigh),
              child: AvatarView(spec: _spec, size: 168, background: widget.background, number: widget.number),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: FilledButton.tonalIcon(
              onPressed: () => _set(AvatarSpec.random()),
              icon: const Text('🎲'),
              label: const Text('Surprise me'),
            ),
          ),
          _Section(
            title: 'Skin tone',
            child: _Swatches(
              colors: skinTones,
              selected: _spec.skin,
              onPick: (c) => _set(_spec.copyWith(skin: c)),
            ),
          ),
          _Section(
            title: 'Hair',
            child: _Options<HairStyle>(
              values: HairStyle.values,
              selected: _spec.hair,
              label: (v) => v.label,
              preview: (v) => _spec.copyWith(hair: v),
              background: widget.background,
              onPick: (v) => _set(_spec.copyWith(hair: v)),
            ),
          ),
          _Section(
            title: 'Hair color',
            child: _Swatches(
              colors: hairColors,
              selected: _spec.hairColor,
              onPick: (c) => _set(_spec.copyWith(hairColor: c)),
            ),
          ),
          _Section(
            title: 'Expression',
            child: _Options<Face>(
              values: Face.values,
              selected: _spec.face,
              label: (v) => v.label,
              preview: (v) => _spec.copyWith(face: v),
              background: widget.background,
              onPick: (v) => _set(_spec.copyWith(face: v)),
            ),
          ),
          _Section(
            title: 'Facial hair',
            child: _Options<Beard>(
              values: Beard.values,
              selected: _spec.beard,
              label: (v) => v.label,
              preview: (v) => _spec.copyWith(beard: v),
              background: widget.background,
              onPick: (v) => _set(_spec.copyWith(beard: v)),
            ),
          ),
          _Section(
            title: 'Eyewear',
            child: _Options<Eyewear>(
              values: Eyewear.values,
              selected: _spec.eyewear,
              label: (v) => v.label,
              preview: (v) => _spec.copyWith(eyewear: v),
              background: widget.background,
              onPick: (v) => _set(_spec.copyWith(eyewear: v)),
            ),
          ),
          _Section(
            title: 'Headband',
            child: _Swatches(
              colors: accessoryColors,
              selected: _spec.headband,
              allowNone: true,
              onPick: (c) => _set(_spec.copyWith(headband: () => c)),
            ),
          ),
          _Section(
            title: 'Jersey',
            child: _Swatches(
              colors: jerseyColors,
              selected: _spec.jersey,
              onPick: (c) => _set(_spec.copyWith(jersey: c!)),
            ),
          ),
          if (widget.initial != null)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Center(
                child: TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: AppColors.loss),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: const Text('Remove avatar (use initials)'),
                  onPressed: () => Navigator.pop(context, const AvatarEditResult(null)),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            icon: const Icon(Icons.check_rounded),
            label: const Text('Save avatar'),
            onPressed: () => Navigator.pop(context, AvatarEditResult(_spec)),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title, padding: const EdgeInsets.fromLTRB(20, 20, 16, 8)),
        child,
      ],
    );
  }
}

/// Row of mini avatars, each showing the current avatar with one option applied.
class _Options<T> extends StatelessWidget {
  const _Options({
    required this.values,
    required this.selected,
    required this.label,
    required this.preview,
    required this.background,
    required this.onPick,
  });
  final List<T> values;
  final T selected;
  final String Function(T) label;
  final AvatarSpec Function(T) preview;
  final Color background;
  final void Function(T) onPick;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final v = values[i];
          final isSel = v == selected;
          return GestureDetector(
            onTap: () => onPick(v),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: isSel ? AppColors.orange : Colors.transparent, width: 3),
                  ),
                  child: AvatarView(spec: preview(v), size: 60, background: background),
                ),
                const SizedBox(height: 2),
                Text(
                  label(v),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                    color: isSel ? cs.onSurface : cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Swatches extends StatelessWidget {
  const _Swatches({required this.colors, required this.selected, required this.onPick, this.allowNone = false});
  final List<Color> colors;
  final int? selected;
  final void Function(int?) onPick;
  final bool allowNone;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget dot({required Color? color, required bool isSel, required VoidCallback onTap}) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color ?? cs.surfaceContainerHigh,
              border: Border.all(
                color: isSel ? AppColors.orange : cs.outline.withValues(alpha: 0.5),
                width: isSel ? 3.5 : 1,
              ),
            ),
            child: color == null ? Icon(Icons.block_rounded, color: cs.onSurfaceVariant, size: 22) : null,
          ),
        );
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (allowNone) ...[
            dot(color: null, isSel: selected == null, onTap: () => onPick(null)),
            const SizedBox(width: 10),
          ],
          for (final c in colors) ...[
            dot(color: c, isSel: selected == c.toARGB32(), onTap: () => onPick(c.toARGB32())),
            const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}
