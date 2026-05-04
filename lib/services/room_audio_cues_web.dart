import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;

/// Plays short synthesised audio tones for room events on the web platform.
///
/// All methods are no-ops on non-web platforms or when Web Audio is unavailable.
/// Each cue is a short oscillator burst so no assets are needed.
class RoomAudioCues {
  RoomAudioCues._();

  static final RoomAudioCues instance = RoomAudioCues._();

  web.AudioContext? _ctx;

  web.AudioContext _getCtx() {
    _ctx ??= web.AudioContext();
    return _ctx!;
  }

  /// Plays a short tone using an OscillatorNode.
  /// [frequency] in Hz, [duration] in milliseconds, [type] is one of
  /// 'sine', 'square', 'sawtooth', 'triangle'.
  void _playTone({
    required double frequency,
    required int durationMs,
    String type = 'sine',
    double gain = 0.18,
  }) {
    if (!kIsWeb) return;
    try {
      final ctx = _getCtx();
      final osc = ctx.createOscillator();
      final gainNode = ctx.createGain();

      osc.type = type;
      osc.frequency.value = frequency;
      gainNode.gain.value = gain;

      osc.connect(gainNode);
      gainNode.connect(ctx.destination);

      final now = ctx.currentTime;
      osc.start(now);
      // Exponential ramp to silence avoids a click artefact.
      gainNode.gain.exponentialRampToValueAtTime(
        0.001,
        now + durationMs / 1000,
      );
      osc.stop(now + durationMs / 1000 + 0.05);
    } catch (_) {
      // AudioContext unavailable — degrade gracefully.
    }
  }

  /// Mobile (non-web) fallback: use haptic feedback patterns to signal events.
  void _hapticLight() {
    if (kIsWeb) return;
    HapticFeedback.lightImpact();
  }

  void _hapticMedium() {
    if (kIsWeb) return;
    HapticFeedback.mediumImpact();
  }

  void _hapticHeavy() {
    if (kIsWeb) return;
    HapticFeedback.heavyImpact();
  }

  void _hapticDouble() {
    if (kIsWeb) return;
    HapticFeedback.lightImpact();
    Future.delayed(
      const Duration(milliseconds: 120),
      HapticFeedback.lightImpact,
    );
  }

  /// Plays a double-tone chord for a richer sound.
  void _playChord({
    required List<double> frequencies,
    required int durationMs,
    String type = 'sine',
    double gain = 0.14,
  }) {
    for (final f in frequencies) {
      _playTone(frequency: f, durationMs: durationMs, type: type, gain: gain);
    }
  }

  // ── Public cues ──────────────────────────────────────────────────────────

  /// Short rising ding when a user joins the room.
  void playUserJoined() {
    if (kIsWeb) {
      _playChord(frequencies: [523.25, 659.25], durationMs: 220);
    } else {
      _hapticLight();
    }
  }

  /// Softer falling tone when a user leaves.
  void playUserLeft() {
    if (kIsWeb) {
      _playTone(frequency: 392.0, durationMs: 180, gain: 0.12);
    } else {
      _hapticLight();
    }
  }

  /// Upbeat three-note fanfare when a gift is received.
  void playGiftReceived() {
    if (kIsWeb) {
      _playTone(frequency: 523.25, durationMs: 120); // C5
      Future.delayed(const Duration(milliseconds: 130), () {
        _playTone(frequency: 659.25, durationMs: 120); // E5
      });
      Future.delayed(const Duration(milliseconds: 260), () {
        _playTone(frequency: 783.99, durationMs: 200); // G5
      });
    } else {
      _hapticMedium();
    }
  }

  /// Clear bell-like tone when someone raises their hand.
  void playHandRaised() {
    if (kIsWeb) {
      _playTone(frequency: 880.0, durationMs: 280, type: 'sine', gain: 0.16);
    } else {
      _hapticDouble();
    }
  }

  /// Ding when a mic request is approved.
  void playMicApproved() {
    if (kIsWeb) {
      _playChord(frequencies: [659.25, 987.77], durationMs: 300);
    } else {
      _hapticHeavy();
    }
  }

  /// Soft ping for incoming chat message.
  void playNewmessage() {
    if (kIsWeb) {
      _playTone(frequency: 660.0, durationMs: 100, gain: 0.10);
    } else {
      _hapticLight();
    }
  }

  /// Distinctive two-tone ping for incoming private message.
  void playPrivatemessage() {
    if (kIsWeb) {
      _playTone(frequency: 880.0, durationMs: 80, gain: 0.16);
      Future.delayed(const Duration(milliseconds: 100), () {
        _playTone(frequency: 1100.0, durationMs: 120, gain: 0.16);
      });
    } else {
      _hapticDouble();
    }
  }

  /// Buzz/nudge: a low-frequency vibrato burst.
  void playBuzz() {
    if (kIsWeb) {
      _playTone(
        frequency: 120.0,
        durationMs: 300,
        type: 'sawtooth',
        gain: 0.22,
      );
    } else {
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 120),
        HapticFeedback.heavyImpact,
      );
      Future.delayed(
        const Duration(milliseconds: 240),
        HapticFeedback.heavyImpact,
      );
    }
  }

  void dispose() {
    try {
      _ctx?.close();
    } catch (_) {}
    _ctx = null;
  }
}
