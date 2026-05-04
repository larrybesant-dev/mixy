import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

// ── Reaction button definitions ───────────────────────────────────────────────

const _kReactions = ['❤️', '🔥', '😍', '👏', '💎'];

// ── Particle entry ─────────────────────────────────────────────────────────────

class _ParticleEntry {
  const _ParticleEntry({
    required this.id,
    required this.emoji,
    required this.leftFraction,
  });
  final int id;
  final String emoji;
  final double leftFraction;
}

// ── Single floating emoji particle ────────────────────────────────────────────

class _EmojiParticle extends StatefulWidget {
  const _EmojiParticle({
    required super.key,
    required this.emoji,
    required this.leftFraction,
    required this.onDone,
  });

  final String emoji;
  final double leftFraction;
  final VoidCallback onDone;

  @override
  State<_EmojiParticle> createState() => _EmojiParticleState();
}

class _EmojiParticleState extends State<_EmojiParticle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _y;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _y = Tween<double>(
      begin: 0,
      end: -200,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 35),
    ]).animate(_ctrl);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.3, end: 1.3), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 75),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) => widget.onDone());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final leftPx = widget.leftFraction * (constraints.maxWidth - 40);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) => Positioned(
            bottom: _y.value + 90,
            left: leftPx,
            child: Opacity(
              opacity: _opacity.value.clamp(0.0, 1.0),
              child: Transform.scale(scale: _scale.value, child: child),
            ),
          ),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 36)),
        );
      },
    );
  }
}

// ── Overlay widget (particle pool + reaction buttons) ─────────────────────────

/// Drop this into the `body` Stack of any full-screen room. Use the [GlobalKey]
/// + [EmojiReactionOverlayState.spawnEmoji] to trigger reactions programmatically
/// (e.g. from incoming Firestore events).
///
/// The reaction button row is shown at the bottom-right of the cam panel and lets
/// users tap to send ephemeral floating emojis.
class EmojiReactionOverlay extends StatefulWidget {
  const EmojiReactionOverlay({super.key});

  @override
  EmojiReactionOverlayState createState() => EmojiReactionOverlayState();
}

class EmojiReactionOverlayState extends State<EmojiReactionOverlay> {
  final List<_ParticleEntry> _particles = [];
  int _nextId = 0;
  final _rng = math.Random();

  /// Spawn a floating emoji particle. Can be called from [GlobalKey.currentState].
  void spawnEmoji(String emoji) {
    if (!mounted) return;
    final id = _nextId++;
    // Randomize horizontal position slightly around the button row area (right side).
    final fraction = 0.60 + _rng.nextDouble() * 0.30;
    setState(() {
      _particles.add(
        _ParticleEntry(id: id, emoji: emoji, leftFraction: fraction),
      );
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() => _particles.removeWhere((p) => p.id == id));
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // Floating particles
        for (final p in _particles)
          _EmojiParticle(
            key: ValueKey(p.id),
            emoji: p.emoji,
            leftFraction: p.leftFraction,
            onDone: () => _remove(p.id),
          ),

        // Reaction button row — bottom-right, above the chat bar
        Positioned(
          right: 12,
          bottom: 80,
          child: _ReactionButtonRow(onReact: spawnEmoji),
        ),
      ],
    );
  }
}

// ── Reaction button row ────────────────────────────────────────────────────────

class _ReactionButtonRow extends StatefulWidget {
  const _ReactionButtonRow({required this.onReact});
  final void Function(String emoji) onReact;

  @override
  State<_ReactionButtonRow> createState() => _ReactionButtonRowState();
}

class _ReactionButtonRowState extends State<_ReactionButtonRow>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _expandCtrl;
  late final Animation<double> _expandAnim;

  @override
  void initState() {
    super.initState();
    _expandCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _expandAnim = CurvedAnimation(parent: _expandCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _expandCtrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandCtrl.forward();
    } else {
      _expandCtrl.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Emoji buttons — expand upward
        SizeTransition(
          axisAlignment: -1,
          sizeFactor: _expandAnim,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _kReactions.map((emoji) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _EmojiBtn(
                  emoji: emoji,
                  onTap: () {
                    widget.onReact(emoji);
                    // Auto-close after tap
                    _toggle();
                  },
                ),
              );
            }).toList(),
          ),
        ),

        // Toggle button — always visible
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _expanded
                  ? VelvetNoir.secondary.withValues(alpha: 0.9)
                  : VelvetNoir.surfaceHighest.withValues(alpha: 0.85),
              shape: BoxShape.circle,
              border: Border.all(
                color: _expanded
                    ? VelvetNoir.secondary
                    : VelvetNoir.outlineVariant,
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedRotation(
              duration: const Duration(milliseconds: 200),
              turns: _expanded ? 0.125 : 0,
              child: Text(
                _expanded ? '✕' : '😊',
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EmojiBtn extends StatelessWidget {
  const _EmojiBtn({required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: VelvetNoir.surfaceHighest.withValues(alpha: 0.85),
          shape: BoxShape.circle,
          border: Border.all(color: VelvetNoir.outlineVariant),
        ),
        alignment: Alignment.center,
        child: Text(emoji, style: const TextStyle(fontSize: 20)),
      ),
    );
  }
}
