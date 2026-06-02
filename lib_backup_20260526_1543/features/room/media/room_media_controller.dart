import 'dart:async';
import 'package:flutter/foundation.dart';
import 'room_media_tier.dart';
import 'participant_media_state.dart';
import 'stream_control.dart';

/// Periodically rebalances participant media tiers based on activity scores
/// and enforces those tiers on the live RTC service via [StreamControl].
///
/// Tier assignment (sorted by score descending):
///   rank 0–2  → fullVideo  (top 3 — host + active speakers)
///   rank 3–11 → lowVideo   (next 9 — stage/recently active)
///   rank 12+  → audioOnly  (everyone else — bandwidth safe)
///
/// Update flow:
///   [queueUpdate]  — enqueue from speaking/camera/join events (safe to call at
///                    any frequency; updates are batched and flushed on each tick)
///   [markSpeaking] — sets isSpeaking with a 2-second auto-decay so rapid SDK
///                    events don't cause flickering speaker states
class RoomMediaController {
  RoomMediaController({required this.streamControl});

  /// Wired RTC enforcement layer.  Created alongside this controller.
  final StreamControl streamControl;

  final Map<String, ParticipantMediaState> _states = {};
  Timer? _rebalanceTimer;

  // Pending updates flushed at the start of each rebalance tick.
  final List<ParticipantMediaState> _pendingUpdates = [];

  // Tracks when each user last triggered a speaking event for decay logic.
  final Map<String, DateTime> _lastSpeakingEvent = {};

  /// How long a user stays "isSpeaking = true" without a new speaking event.
  static const Duration _speakingDecayWindow = Duration(seconds: 2);

  // Tier thresholds — adjust as needed.
  static const int _fullVideoMax = 3;
  static const int _lowVideoMax = 12;

  void start() {
    _rebalanceTimer?.cancel();
    _rebalanceTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _rebalance(),
    );
  }

  void stop() {
    _rebalanceTimer?.cancel();
    _rebalanceTimer = null;
    _pendingUpdates.clear();
    _lastSpeakingEvent.clear();
  }

  /// Enqueue a state update. Safe to call on every SDK event — updates are
  /// batched and applied atomically at the next rebalance tick.
  void queueUpdate(ParticipantMediaState state) {
    _pendingUpdates.add(state);
  }

  /// Convenience: mark a user as currently speaking and queue the update.
  /// Repeated calls reset the 2-second decay window without creating jitter.
  void markSpeaking(String userId) {
    _lastSpeakingEvent[userId] = DateTime.now();
    final current = _states[userId];
    if (current != null && !current.isSpeaking) {
      queueUpdate(current.copyWith(isSpeaking: true));
    }
  }

  /// Remove a participant (on leave / kick).
  void removeParticipant(String userId) {
    _states.remove(userId);
    _lastSpeakingEvent.remove(userId);
    streamControl.unregisterUid(userId);
  }

  /// Current snapshot of all states after the last rebalance.
  List<ParticipantMediaState> get states =>
      List.unmodifiable(_states.values.toList());

  void _rebalance() {
    // 1. Flush pending updates atomically.
    if (_pendingUpdates.isNotEmpty) {
      for (final p in _pendingUpdates) {
        _states[p.userId] = p;
      }
      _pendingUpdates.clear();
    }

    if (_states.isEmpty) return;

    // 2. Decay speaking state for users past the window.
    final now = DateTime.now();
    for (final userId in _states.keys.toList()) {
      final lastEvent = _lastSpeakingEvent[userId];
      final state = _states[userId]!;
      if (state.isSpeaking &&
          (lastEvent == null ||
              now.difference(lastEvent) > _speakingDecayWindow)) {
        _states[userId] = state.copyWith(isSpeaking: false);
      }
    }

    // 3. Assign tiers by score.
    final sorted = _states.values.toList()
      ..sort((a, b) => b.activityScore.compareTo(a.activityScore));

    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      final newTier = i < _fullVideoMax
          ? MediaTier.fullVideo
          : i < _lowVideoMax
              ? MediaTier.lowVideo
              : MediaTier.audioOnly;

      if (p.tier != newTier) {
        _states[p.userId] = p.copyWith(tier: newTier);
      }
    }

    // 4. Enforce tier decisions on the live RTC service.
    streamControl.applyTiers(_states.values.toList());

    debugPrint(
      '🔁 Media rebalance: ${_states.length} users, '
      'fullVideo=${sorted.take(_fullVideoMax).length}',
    );
  }
}
