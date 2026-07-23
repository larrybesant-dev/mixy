import 'dart:async';

import 'package:flutter/material.dart';

/// A full-screen flash overlay that plays when the current user receives a buzz.
///
/// Usage:
/// ```dart
/// final GlobalKey<BuzzOverlayState> _buzzKey = GlobalKey();
/// BuzzOverlay(key: _buzzKey, child: Scaffold(...))
/// // Later:
/// _buzzKey.currentState?.triggerBuzz('Larry buzzed you!');
/// ```
class BuzzOverlay extends StatefulWidget {
  const BuzzOverlay({super.key, required this.child});

  final Widget child;

  @override
  BuzzOverlayState createState() => BuzzOverlayState();
}

class BuzzOverlayState extends State<BuzzOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  String _label = '';
  Timer? _clearTimer;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _opacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  /// Trigger a buzz flash with an optional sender label.
  void triggerBuzz(String label) {
    _clearTimer?.cancel();
    setState(() => _label = label);
    _ctrl.forward(from: 0);
    _clearTimer = Timer(const Duration(milliseconds: 1400), () {
      _ctrl.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _opacity,
            builder: (context, _) {
              if (_opacity.value <= 0.001) return const SizedBox.shrink();
              return Opacity(
                opacity: _opacity.value * 0.65,
                child: ColoredBox(
                  color: const Color(0xFFFF6E84),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⚡', style: TextStyle(fontSize: 22)),
                            const SizedBox(width: 8),
                            Text(
                              _label.isNotEmpty ? _label : 'You got buzzed!',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}



