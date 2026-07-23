import 'package:flutter/material.dart';

/// A single floating gift emoji that animates upward then fades.
/// Call [onDone] when the animation completes so the parent can remove it.
class FloatingGiftParticle extends StatefulWidget {
  final String emoji;
  final double leftFraction; // 0.0–1.0 fraction of available width
  final VoidCallback onDone;

  const FloatingGiftParticle({
    super.key,
    required this.emoji,
    required this.leftFraction,
    required this.onDone,
  });

  @override
  State<FloatingGiftParticle> createState() => _FloatingGiftParticleState();
}

class _FloatingGiftParticleState extends State<FloatingGiftParticle>
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
      duration: const Duration(milliseconds: 2200),
    );

    _y = Tween<double>(
      begin: 0,
      end: -220,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 8),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 65),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 27),
    ]).animate(_ctrl);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 1.4), weight: 18),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 10),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 72),
    ]).animate(_ctrl);

    _ctrl.forward().then((_) {
      widget.onDone();
    });
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
        final leftPx = widget.leftFraction * (constraints.maxWidth - 56);
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            return Positioned(
              bottom: _y.value + 120,
              left: leftPx,
              child: Opacity(
                opacity: _opacity.value.clamp(0.0, 1.0),
                child: Transform.scale(scale: _scale.value, child: child),
              ),
            );
          },
          child: Text(widget.emoji, style: const TextStyle(fontSize: 42)),
        );
      },
    );
  }
}

/// Overlay that manages a pool of [FloatingGiftParticle] widgets.
class FloatingGiftOverlay extends StatefulWidget {
  const FloatingGiftOverlay({super.key});

  @override
  FloatingGiftOverlayState createState() => FloatingGiftOverlayState();
}

class FloatingGiftOverlayState extends State<FloatingGiftOverlay> {
  final List<_ParticleEntry> _particles = [];
  int _nextId = 0;

  void spawnGift(String emoji) {
    if (!mounted) return;
    final id = _nextId++;
    final fraction = 0.1 + (id % 5) * 0.18;
    setState(() {
      _particles.add(
        _ParticleEntry(id: id, emoji: emoji, leftFraction: fraction.toDouble()),
      );
    });
  }

  void _remove(int id) {
    if (!mounted) return;
    setState(() {
      _particles.removeWhere((p) => p.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_particles.isEmpty) return const SizedBox.shrink();
    return IgnorePointer(
      child: Stack(
        children: _particles
            .take(12)
            .map(
              (entry) => FloatingGiftParticle(
                key: ValueKey(entry.id),
                emoji: entry.emoji,
                leftFraction: entry.leftFraction,
                onDone: () => _remove(entry.id),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _ParticleEntry {
  final int id;
  final String emoji;
  final double leftFraction;
  const _ParticleEntry({
    required this.id,
    required this.emoji,
    required this.leftFraction,
  });
}



