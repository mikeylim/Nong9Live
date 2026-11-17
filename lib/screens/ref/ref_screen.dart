import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/app_store.dart';
import '../../services/sound_service.dart';
import '../../theme/app_theme.dart';

class _Pad {
  const _Pad(this.emoji, this.label, this.sub, this.sfx, this.color, [this.lines = const []]);
  final String emoji;
  final String label;
  final String sub;
  final Sfx sfx;
  final Color color;

  /// Announcer lines (one picked at random) when the voice is on.
  final List<String> lines;
}

const _pads = <_Pad>[
  _Pad('🟨', 'FOUL', 'whistle', Sfx.whistle, Color(0xFFF59E0B), ['Foul!', 'That\'s a foul!']),
  _Pad('🏀', '+1', 'free throw', Sfx.score1, Color(0xFF16A34A), ['Free throw is good!', 'And one!']),
  _Pad('🔥', '+2', 'bucket', Sfx.score2, Color(0xFF16A34A), ['Bucket!', 'Count it!', 'Easy money!']),
  _Pad('💥', '+3', 'bang!', Sfx.score3, Color(0xFFFF6B1A), ['Bang! From downtown!', 'Three pointer!', 'Splash!']),
  _Pad('💨', 'AIRBALL', 'sad trombone', Sfx.airball, Color(0xFFEC4899), ['Air ball!', 'Air... ball!']),
  _Pad('🧱', 'BRICK', 'clank', Sfx.brick, Color(0xFF78716C), ['Brick!', 'Clank!']),
  _Pad('🚫', 'BLOCK', 'rejected', Sfx.block, Color(0xFF8B5CF6), [
    'Rejected!',
    'Get that outta here!',
    'Not in my house!',
  ]),
  _Pad('🥷', 'STEAL', 'pickpocket', Sfx.steal, Color(0xFF6366F1), ['Stolen!', 'Picked his pocket!']),
  _Pad('🚶', 'TRAVEL', 'double whistle', Sfx.whistleDouble, Color(0xFFD97706), ['Traveling!', 'That\'s a walk!']),
  _Pad('⏱️', 'TIMEOUT', 'horn', Sfx.timeout, Color(0xFF3B82F6), ['Timeout!']),
  _Pad('🙌', 'CROWD', 'cheer', Sfx.crowd, Color(0xFF14B8A6)),
  _Pad('📯', 'AIR HORN', 'hype', Sfx.airhorn, Color(0xFFEF4444)),
  _Pad('🏁', 'TIP-OFF', 'let\'s go', Sfx.tipoff, Color(0xFF06B6D4), ['Let\'s go!', 'Ball is up!']),
  _Pad('📣', 'WHISTLE', 'long', Sfx.whistleLong, Color(0xFFCA8A04)),
  _Pad('🚨', 'GAME OVER', 'buzzer', Sfx.buzzer, Color(0xFFDC2626), ['That\'s the game!', 'Game over!']),
];

const _phrases = [
  'And one!',
  'Ball don\'t lie!',
  'Check ball!',
  'Next!',
  'Game point!',
  'Run it back!',
  'Who\'s got next?',
  'Defense! Defense!',
  'Ice cold!',
  'He\'s on fire!',
];

class RefScreen extends StatefulWidget {
  const RefScreen({super.key});

  @override
  State<RefScreen> createState() => _RefScreenState();
}

class _RefScreenState extends State<RefScreen> {
  final _say = TextEditingController();
  int _phrase = 0;

  // Shot clock
  int _shotLength = 24;
  int _remainingMs = 24000;
  DateTime? _startedAt;
  int _baseMs = 24000;
  Timer? _timer;
  int _lastBeep = -1;

  late final SoundService _sound;

  @override
  void initState() {
    super.initState();
    // No preload here: the tab is built at startup (IndexedStack). The shell
    // preloads when the Ref tab is first opened.
    _sound = context.read<SoundService>();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _say.dispose();
    super.dispose();
  }

  void _hit(_Pad pad) {
    HapticFeedback.mediumImpact();
    _sound.play(pad.sfx);
    final store = context.read<AppStore>();
    if (store.settings.announcer && pad.lines.isNotEmpty) {
      final line = pad.lines[_phrase++ % pad.lines.length];
      Future.delayed(const Duration(milliseconds: 600), () => _sound.say(line));
    }
  }

  // ------------------------------------------------------------ shot clock

  bool get _running => _startedAt != null;

  void _toggleClock() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_running) {
        _remainingMs = _left;
        _startedAt = null;
        _timer?.cancel();
      } else {
        if (_remainingMs <= 0) _remainingMs = _shotLength * 1000;
        _baseMs = _remainingMs;
        _startedAt = DateTime.now();
        _lastBeep = -1;
        _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tickClock());
      }
    });
  }

  int get _left {
    if (_startedAt == null) return _remainingMs;
    return (_baseMs - DateTime.now().difference(_startedAt!).inMilliseconds).clamp(0, _baseMs);
  }

  void _tickClock() {
    final left = _left;
    final secs = (left / 1000).ceil();
    if (secs <= 5 && secs > 0 && secs != _lastBeep) {
      _lastBeep = secs;
      _sound.play(Sfx.beep);
    }
    if (left <= 0) {
      _timer?.cancel();
      _startedAt = null;
      _remainingMs = 0;
      HapticFeedback.heavyImpact();
      _sound.play(Sfx.buzzer);
    }
    if (mounted) setState(() {});
  }

  void _reset(int seconds) {
    HapticFeedback.selectionClick();
    setState(() {
      _shotLength = seconds;
      _remainingMs = seconds * 1000;
      _baseMs = _remainingMs;
      if (_running) _startedAt = DateTime.now();
      _lastBeep = -1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = store.settings;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ref mode'),
        actions: [
          IconButton(
            tooltip: s.announcer ? 'Announcer voice on' : 'Announcer voice off',
            icon: Icon(
              s.announcer ? Icons.record_voice_over_rounded : Icons.voice_over_off_rounded,
              color: s.announcer ? AppColors.orange : null,
            ),
            onPressed: () {
              s.announcer = !s.announcer;
              store.saveSettings();
            },
          ),
          IconButton(
            tooltip: 'Stop all sounds',
            icon: const Icon(Icons.stop_circle_outlined),
            onPressed: _sound.stopAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
        children: [
          _shotClock(cs),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.95,
            ),
            itemCount: _pads.length,
            itemBuilder: (_, i) => _SoundPad(pad: _pads[i], onTap: () => _hit(_pads[i])),
          ),
          const SizedBox(height: 20),
          Text(
            'SAY ANYTHING',
            style: TextStyle(
              fontFamily: displayFont,
              fontWeight: FontWeight.w800,
              fontSize: 17,
              letterSpacing: 1.2,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _say,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(hintText: 'Type something for the announcer'),
                  onSubmitted: (v) => _sound.say(v),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: AppColors.orange, minimumSize: const Size(52, 52)),
                onPressed: () => _sound.say(_say.text),
                icon: const Icon(Icons.campaign_rounded, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final p in _phrases) ActionChip(label: Text(p), onPressed: () => _sound.say(p))],
          ),
        ],
      ),
    );
  }

  Widget _shotClock(ColorScheme cs) {
    final left = _left;
    final secs = left / 1000;
    final danger = secs <= 5;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(colors: [Color(0xFF232838), Color(0xFF161925)]),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggleClock,
            child: Container(
              width: 128,
              height: 104,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _running ? (danger ? AppColors.loss : AppColors.orange) : Colors.white24,
                  width: 2,
                ),
              ),
              child: Text(
                secs < 10 && secs > 0 ? secs.toStringAsFixed(1) : '${secs.ceil()}',
                style: scoreStyle(64, color: danger && left > 0 ? const Color(0xFFFF4D4D) : const Color(0xFFFFB020)),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'SHOT CLOCK',
                  style: TextStyle(
                    color: Colors.white60,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: _toggleClock,
                  icon: Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  label: Text(_running ? 'Pause' : 'Start'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final v in [24, 14]) ...[
                      if (v == 14) const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => _reset(v),
                          child: Text('$v'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoundPad extends StatefulWidget {
  const _SoundPad({required this.pad, required this.onTap});
  final _Pad pad;
  final VoidCallback onTap;

  @override
  State<_SoundPad> createState() => _SoundPadState();
}

class _SoundPadState extends State<_SoundPad> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.pad.color;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(c, Colors.white, 0.12)!, Color.lerp(c, Colors.black, 0.28)!],
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: _down ? 0.15 : 0.35),
                blurRadius: _down ? 4 : 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.pad.emoji, style: const TextStyle(fontSize: 34)),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    widget.pad.label,
                    style: const TextStyle(
                      fontFamily: displayFont,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Text(
                  widget.pad.sub,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
