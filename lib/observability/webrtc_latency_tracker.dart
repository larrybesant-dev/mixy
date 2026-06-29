import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Tracks WebRTC signaling latency across the Firestore → PeerConnection → UI pipeline.
///
/// **Goal:** Detect when network delays are causing noticeable lag in video grid rendering.
///
/// **Key Thresholds:**
/// - 500ms: Normal (acceptable)
/// - 1000ms: Noticeable (user might perceive slight lag)
/// - 2000ms: Critical (reconnecting prompt should appear)
///
class WebRtcLatencyTracker {
  static const String _tag = '[WebRtcLatency]';
  static const Duration _warningThreshold = Duration(milliseconds: 1000);
  static const Duration _criticalThreshold = Duration(milliseconds: 2000);

  // Per-peer latency tracking
  final Map<String, _PeerLatencyState> _peerStates = {};
  
  // Callbacks for UI integration
  VoidCallback? onLatencyWarning;  // 1000ms < latency < 2000ms
  VoidCallback? onLatencyCritical; // latency >= 2000ms
  VoidCallback? onLatencyRecovered; // latency normalized

  /// Start tracking a signaling attempt for a peer.
  void startSignalingTimer(String peerId) {
    _peerStates[peerId] = _PeerLatencyState(
      peerId: peerId,
      signalingStartTime: DateTime.now(),
    );
    debugPrint('$_tag 🟢 Signaling started for peer: $peerId');
  }

  /// Record when offer/answer is sent to Firestore.
  void recordOfferAnswerSent(String peerId, String type) {
    final state = _peerStates[peerId];
    if (state == null) {
      debugPrint('$_tag ⚠️ No latency state for peer: $peerId');
      return;
    }
    
    state.sdpSentTime = DateTime.now();
    final elapsed = state.sdpSentTime!.difference(state.signalingStartTime).inMilliseconds;
    debugPrint('$_tag 📤 $type sent to Firestore in ${elapsed}ms');
  }

  /// Record when the remote peer's offer/answer is received from Firestore.
  void recordRemoteDescriptionReceived(String peerId, String type) {
    final state = _peerStates[peerId];
    if (state == null) return;
    
    state.remoteDescriptionReceivedTime = DateTime.now();
    final elapsed = state.remoteDescriptionReceivedTime!
        .difference(state.sdpSentTime ?? state.signalingStartTime)
        .inMilliseconds;
    debugPrint('$_tag 📥 Remote $type received in ${elapsed}ms (from Firestore)');
  }

  /// Record when `setRemoteDescription()` completes.
  void recordRemoteDescriptionApplied(String peerId) {
    final state = _peerStates[peerId];
    if (state == null) return;
    
    state.remoteDescriptionAppliedTime = DateTime.now();
    final elapsed = state.remoteDescriptionAppliedTime!
        .difference(state.remoteDescriptionReceivedTime ?? state.signalingStartTime)
        .inMilliseconds;
    debugPrint('$_tag ✅ Remote description applied in ${elapsed}ms');
  }

  /// Record when ICE connection transitions to "CONNECTED" state.
  void recordPeerConnectionEstablished(String peerId) {
    final state = _peerStates[peerId];
    if (state == null) return;
    
    state.connectionEstablishedTime = DateTime.now();
    final totalLatency = state.connectionEstablishedTime!
        .difference(state.signalingStartTime)
        .inMilliseconds;
    
    debugPrint(
      '$_tag 🚀 Peer connection established in ${totalLatency}ms\n'
      '  Breakdown:\n'
      '  - Signaling → Firestore: ${(state.sdpSentTime?.difference(state.signalingStartTime).inMilliseconds ?? 0)}ms\n'
      '  - Firestore RTT: ${(state.remoteDescriptionReceivedTime?.difference(state.sdpSentTime ?? state.signalingStartTime).inMilliseconds ?? 0)}ms\n'
      '  - Description application: ${(state.remoteDescriptionAppliedTime?.difference(state.remoteDescriptionReceivedTime ?? state.signalingStartTime).inMilliseconds ?? 0)}ms\n'
      '  - ICE gathering: ${(state.connectionEstablishedTime?.difference(state.remoteDescriptionAppliedTime ?? state.signalingStartTime).inMilliseconds ?? 0)}ms'
    );

    // Trigger UI callbacks based on latency thresholds
    if (totalLatency >= _criticalThreshold.inMilliseconds) {
      debugPrint('$_tag 🔴 CRITICAL: Latency ${totalLatency}ms exceeds threshold');
      onLatencyCritical?.call();
    } else if (totalLatency >= _warningThreshold.inMilliseconds) {
      debugPrint('$_tag 🟡 WARNING: Latency ${totalLatency}ms is elevated');
      onLatencyWarning?.call();
    }

    // Record timeline event for Dart DevTools
    developer.Timeline.startSync('WebRTC:PeerConnectionEstablished');
    developer.Timeline.instantSync('latency_ms', arguments: {'value': totalLatency});
    developer.Timeline.finishSync();
  }

  /// Record when a peer connection is closed/removed.
  void recordPeerConnectionClosed(String peerId) {
    final state = _peerStates.remove(peerId);
    if (state != null) {
      debugPrint('$_tag ❌ Peer connection closed: $peerId');
    }
  }

  /// Get current latency stats for diagnostics.
  Map<String, dynamic> getLatencyStats(String peerId) {
    final state = _peerStates[peerId];
    if (state == null) return {};

    final now = DateTime.now();
    final totalLatency = state.connectionEstablishedTime != null
        ? state.connectionEstablishedTime!.difference(state.signalingStartTime).inMilliseconds
        : now.difference(state.signalingStartTime).inMilliseconds;

    return {
      'peerId': peerId,
      'totalLatencyMs': totalLatency,
      'signalingPhaseMs': state.sdpSentTime?.difference(state.signalingStartTime).inMilliseconds ?? 0,
      'firestoreRttMs': state.remoteDescriptionReceivedTime?.difference(state.sdpSentTime ?? state.signalingStartTime).inMilliseconds ?? 0,
      'descriptionApplicationMs': state.remoteDescriptionAppliedTime?.difference(state.remoteDescriptionReceivedTime ?? state.signalingStartTime).inMilliseconds ?? 0,
      'iceGatheringMs': state.connectionEstablishedTime?.difference(state.remoteDescriptionAppliedTime ?? state.signalingStartTime).inMilliseconds ?? 0,
      'status': state.connectionEstablishedTime != null ? 'established' : 'pending',
    };
  }

  /// Get the latest (most recent) latency measurement in milliseconds.
  ///
  /// Returns the total latency of the most recently established peer connection,
  /// or 0 if no peer connections have been tracked.
  int getLatestLatencyMs() {
    if (_peerStates.isEmpty) return 0;

    int maxLatency = 0;
    DateTime? maxTimestamp;

    for (final state in _peerStates.values) {
      // Use the most recent connection established time
      if (state.connectionEstablishedTime != null) {
        final latency = state.connectionEstablishedTime!
            .difference(state.signalingStartTime)
            .inMilliseconds;
        
        if (maxTimestamp == null || state.connectionEstablishedTime!.isAfter(maxTimestamp)) {
          maxLatency = latency;
          maxTimestamp = state.connectionEstablishedTime;
        }
      }
    }

    return maxLatency;
  }

  /// Reset all tracking data.
  void reset() {
    _peerStates.clear();
    debugPrint('$_tag 🔄 Latency tracker reset');
  }
}

/// Internal state container for a single peer's latency measurements.
class _PeerLatencyState {
  final String peerId;
  final DateTime signalingStartTime;
  
  DateTime? sdpSentTime;                      // When offer/answer sent to Firestore
  DateTime? remoteDescriptionReceivedTime;    // When remote offer/answer received from Firestore
  DateTime? remoteDescriptionAppliedTime;     // When setRemoteDescription() applied
  DateTime? connectionEstablishedTime;        // When ICE connection reaches "CONNECTED"

  _PeerLatencyState({
    required this.peerId,
    required this.signalingStartTime,
  });
}
