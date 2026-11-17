import 'package:flutter/material.dart';

import '../data/photo_store.dart';
import '../models/game.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';

class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({super.key, required this.player, this.size = 44, this.ring});

  final Player? player;
  final double size;

  /// Optional colored ring (e.g. team color).
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final photo = PhotoStore.fileFor(p?.photoPath);
    final color = p?.color ?? Colors.grey;
    Widget inner;
    if (photo != null) {
      inner = ClipOval(
        child: Image.file(photo, width: size, height: size, fit: BoxFit.cover, cacheWidth: (size * 3).round()),
      );
    } else {
      inner = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(color, Colors.white, 0.15)!, Color.lerp(color, Colors.black, 0.25)!],
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          p?.initials ?? '?',
          style: TextStyle(
            fontFamily: displayFont,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.42,
            color: Colors.white,
            height: 1,
          ),
        ),
      );
    }
    if (ring == null) return inner;
    return Container(
      padding: EdgeInsets.all(size > 60 ? 3 : 2),
      decoration: BoxDecoration(shape: BoxShape.circle, color: ring),
      child: inner,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.padding});
  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 24, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontFamily: displayFont,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: 1.2,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.emoji, required this.title, this.message, this.action});
  final String emoji;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 56)),
            const SizedBox(height: 12),
            Text(title, style: tt.headlineSmall, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

/// Small label + big number.
class StatBox extends StatelessWidget {
  const StatBox({super.key, required this.label, required this.value, this.sub, this.highlight = false});
  final String label;
  final String value;
  final String? sub;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: highlight ? AppColors.orange.withValues(alpha: 0.14) : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: scoreStyle(28, color: highlight ? AppColors.orange : cs.onSurface, weight: FontWeight.w800)),
          ),
          if (sub != null)
            Text(sub!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class OvrBadge extends StatelessWidget {
  const OvrBadge({super.key, required this.overall, this.size = 1, this.onColor = false});
  final int overall;
  final double size;

  /// Sitting on a colored header: use a dark backing so the tier color reads.
  final bool onColor;

  Color get _color {
    if (overall >= 85) return AppColors.gold;
    if (overall >= 75) return const Color(0xFF34D399);
    if (overall >= 65) return const Color(0xFF60A5FA);
    return const Color(0xFFA1A1AA);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7 * size, vertical: 3 * size),
      decoration: BoxDecoration(
        color: onColor ? Colors.black.withValues(alpha: 0.55) : _color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8 * size),
        border: Border.all(color: _color.withValues(alpha: onColor ? 0.9 : 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$overall', style: scoreStyle(16 * size, color: _color, weight: FontWeight.w900)),
          SizedBox(width: 3 * size),
          Text('OVR', style: TextStyle(fontSize: 9 * size, fontWeight: FontWeight.w800, color: _color)),
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, required this.color, this.filled = false, this.icon});
  final String text;
  final Color color;
  final bool filled;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 12, color: filled ? Colors.white : color), const SizedBox(width: 3)],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              color: filled ? Colors.white : color,
            ),
          ),
        ],
      ),
    );
  }
}

class LivePill extends StatefulWidget {
  const LivePill({super.key});

  @override
  State<LivePill> createState() => _LivePillState();
}

class _LivePillState extends State<LivePill> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.live, borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 5),
          const Text('LIVE',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class TeamSwatch extends StatelessWidget {
  const TeamSwatch({super.key, required this.color, this.size = 14});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: cs.outline.withValues(alpha: 0.6)),
      ),
    );
  }
}

class PositionBadges extends StatelessWidget {
  const PositionBadges({super.key, required this.player, this.dense = false});
  final Player player;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final positions = player.positions.toList()..sort((a, b) => a.index.compareTo(b.index));
    if (positions.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 4,
      children: [
        for (final p in positions)
          Container(
            padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 7, vertical: dense ? 1 : 2),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              dense ? p.short : p.label,
              style: TextStyle(fontSize: dense ? 11 : 12, fontWeight: FontWeight.w800, color: cs.onSurfaceVariant),
            ),
          ),
      ],
    );
  }
}

/// Lets the user pick a team shirt color + name.
Future<(String, Color)?> pickTeamColor(BuildContext context, {Color? current}) {
  return showModalBottomSheet<(String, Color)>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team color', style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final (name, color) in teamColorPresets)
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx, (name, color)),
                    child: Column(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              width: current?.toARGB32() == color.toARGB32() ? 3 : 1,
                              color: current?.toARGB32() == color.toARGB32()
                                  ? AppColors.orange
                                  : Theme.of(ctx).colorScheme.outline,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'OK',
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.loss) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
}
