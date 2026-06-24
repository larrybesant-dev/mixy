/// Vibe Theme Provider
/// #8 — Adaptive Neon Glow: the app's accent color shifts dynamically
/// based on the user's current vibe context (room vibe > profile vibe > default).
///
/// Usage:
///   final accentColor = ref.watch(vibeAccentProvider);
///   final vibeGlow = ref.watch(vibeGlowProvider);
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Neon palette keyed by vibe name — same as rooms/home pages.
const kVibeColorPalette = <String, Color>{
  'Chill': Color(0xFF4A90FF),
  'Hype': Color(0xFFFF4D8B),
  'Deep Talk': Color(0xFF8B5CF6),
  'Late Night': Color(0xFF6366F1),
  'Study': Color(0xFF00E5CC),
  'Party': Color(0xFFFFAB00),
};

/// Default accent when no vibe context is active.
const _kDefaultAccent = Color(0xFF4A90FF);

// ─────────────────────────────────────────────────────────────────────────────

/// The currently active vibe (null = no override, uses user profile vibe).
/// Write to this to change the app-wide accent colour:
///   ref.read(activeVibeProvider.notifier).set('Hype');
class _ActiveVibeNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  // ignore: use_setters_to_change_properties
  void set(String? vibe) => state = vibe;
}

final activeVibeProvider = NotifierProvider<_ActiveVibeNotifier, String?>(
  _ActiveVibeNotifier.new,
);

/// The resolved accent color for the current vibe context.
final vibeAccentProvider = Provider<Color>((ref) {
  final vibe = ref.watch(activeVibeProvider);
  return kVibeColorPalette[vibe] ?? _kDefaultAccent;
});

/// A glow BoxShadow list for the current vibe accent — ready to use in
/// BoxDecoration.boxShadow.
final vibeGlowProvider = Provider<List<BoxShadow>>((ref) {
  final color = ref.watch(vibeAccentProvider);
  return [
    BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16),
    BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 32),
  ];
});

/// Convenience: returns palette color for any vibe key, or default.
Color vibeColor(String? vibe) => kVibeColorPalette[vibe] ?? _kDefaultAccent;
