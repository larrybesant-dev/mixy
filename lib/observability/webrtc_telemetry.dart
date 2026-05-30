import 'package:flutter/foundation.dart';

import '../core/telemetry/telemetry_config.dart';
import 'production_alerts.dart';

/// WebRTC session-level telemetry for the room network layer.
///
/// Tracks per-session:
/// * SDP offer/answer exchanges (signaling volume)
/// * ICE candidate deliveries (negotiation cost)
/// * Reconnect attempts (connection instability)
/// * Peer connection failures
/// * Stream refresh cycles (broadcaster stream switches)
///
/// Call [beginSession] when a room is joined and [endSession] when it ends.
/// The last completed session's snapshot is accessible via [lastSession].
///
/// All methods are no-ops in release mode.
abstract final class WebRtcTelemetry {
  // ─── Session state ─────────────────────────────────────────────────────────
  static _SessionCounters? _current;
  static WebRtcSessionSnapshot? _lastSession;

  /// Sampling divisor for ICE candidates in [TelemetryMode.standard].
  /// Records 1 of every [_iceSampleRate] candidates to reduce noise
  /// in high-traffic sessions without losing burst detection.
  static const int _iceSampleRate = 5;
  // ─── Public API ────────────────────────────────────────────────────────────

  /// Start tracking a new WebRTC session for [roomId].
  /// Ends any previous session automatically.
  static void beginSession(String roomId) {
    if (!TelemetryConfig.isActive) return;
    if (_current != null) _finalise();
    _current = _SessionCounters(roomId: roomId, startedAt: DateTime.now());
    if (TelemetryConfig.allows(LogTier.operational)) {
      debugPrint('[WebRtcTelemetry] session started — room=$roomId');
    }
  }

  /// End the current session and freeze the snapshot.
  static void endSession() {
    if (!TelemetryConfig.isActive) return;
    if (_current == null) return;
    _finalise();
    if (TelemetryConfig.allows(LogTier.operational)) {
      final s = _lastSession!;
      debugPrint(
        '[WebRtcTelemetry] session ended — '
        'offers=${s.offersSent} answers=${s.answersReceived} '
        'reconnects=${s.reconnectAttempts} failures=${s.peerFailures} '
        'streamRefreshes=${s.streamRefreshes} '
        'iceCandidates=${s.iceCandidatesSent}',
      );
    }
  }

  /// Record that an SDP offer was sent (viewer → broadcaster signaling).
  static void recordOfferSent() {
    if (!TelemetryConfig.isActive || _current == null) return;
    _current!.offersSent++;
  }

  /// Record that an SDP answer was received (broadcaster → viewer signaling).
  static void recordAnswerReceived() {
    if (!TelemetryConfig.isActive || _current == null) return;
    _current!.answersReceived++;
  }

  /// Record an ICE candidate sent to Firestore signaling.
  ///
  /// In [TelemetryMode.standard] mode only 1 in [_iceSampleRate] candidates
  /// is counted to reduce noise in high-traffic sessions.
  static void recordIceCandidateSent() {
    if (!TelemetryConfig.isActive || _current == null) return;
    _current!.iceCandidatesRaw++;
    if (TelemetryConfig.mode == TelemetryMode.debug ||
        _current!.iceCandidatesRaw % _iceSampleRate == 0) {
      _current!.iceCandidatesSent++;
    }
  }

  /// Record a reconnect attempt (connection dropped and retried).
  static void recordReconnect({String? broadcasterId}) {
    if (!TelemetryConfig.isActive || _current == null) return;
    _current!.reconnectAttempts++;
    _checkReconnectBurst();
    if (TelemetryConfig.allows(LogTier.operational)) {
      debugPrint(
        '[WebRtcTelemetry] 🔄 reconnect #${_current!.reconnectAttempts}'
        '${broadcasterId != null ? ' → $broadcasterId' : ''}',
      );
    }
  }

  /// Record a peer connection failure (RTCPeerConnectionStateFailed).
  static void recordPeerFailure({String? broadcasterId}) {
    if (!TelemetryConfig.isActive || _current == null) return;
    _current!.peerFailures++;
    ProductionAlertSystem.fireCustomAlert(
      id: 'webrtc_peer_fail_${broadcasterId ?? 'unknown'}',
      message:
          'WebRTC peer failed${broadcasterId != null ? ': $broadcasterId' : ''}',
      level: AlertLevel.warning,
    );
    if (TelemetryConfig.allows(LogTier.operational)) {
      debugPrint(
        '[WebRtcTelemetry] ⚠️ peer failure #${_current!.peerFailures}'
        '${broadcasterId != null ? ' ($broadcasterId)' : ''}',
      );
    }
  }

  /// Record a stream refresh cycle (broadcaster switched MediaStream).
  static void recordStreamRefresh({String? broadcasterId}) {
    if (!TelemetryConfig.isActive || _current == null) return;
    _current!.streamRefreshes++;
    if (TelemetryConfig.allows(LogTier.debug)) {
      debugPrint(
        '[WebRtcTelemetry] 🔁 stream refresh #${_current!.streamRefreshes}'
        '${broadcasterId != null ? ' ← $broadcasterId' : ''}',
      );
    }
  }

  /// Snapshot of the current active session (null if no session).
  static WebRtcSessionSnapshot? get currentSession => _current?.toSnapshot();

  /// Snapshot of the last completed session (null if none yet).
  static WebRtcSessionSnapshot? get lastSession => _lastSession;

  // ─── Internals ─────────────────────────────────────────────────────────────

  static void _finalise() {
    if (_current == null) return;
    _lastSession = _current!.toSnapshot(endedAt: DateTime.now());
    _current = null;
  }

  static void _checkReconnectBurst() {
    final c = _current;
    if (c == null) return;
    if (c.reconnectAttempts == 5) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'webrtc_reconnect_burst_${c.roomId}',
        message:
            'WebRTC reconnect burst [${c.roomId}]: ${c.reconnectAttempts} reconnects this session',
        level: AlertLevel.warning,
      );
    } else if (c.reconnectAttempts == 10) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'webrtc_reconnect_critical_${c.roomId}',
        message:
            'WebRTC reconnect storm [${c.roomId}]: ${c.reconnectAttempts} reconnects this session',
        level: AlertLevel.critical,
      );
    }
  }
}

// ─── Counters ─────────────────────────────────────────────────────────────

class _SessionCounters {
  _SessionCounters({required this.roomId, required this.startedAt});

  final String roomId;
  final DateTime startedAt;

  int offersSent = 0;
  int answersReceived = 0;

  /// Sampled ICE candidate count (reported in snapshots).
  int iceCandidatesSent = 0;

  /// Raw (unsampled) ICE candidate count for sampling arithmetic.
  int iceCandidatesRaw = 0;
  int reconnectAttempts = 0;
  int peerFailures = 0;
  int streamRefreshes = 0;

  WebRtcSessionSnapshot toSnapshot({DateTime? endedAt}) {
    return WebRtcSessionSnapshot(
      roomId: roomId,
      startedAt: startedAt,
      endedAt: endedAt,
      offersSent: offersSent,
      answersReceived: answersReceived,
      iceCandidatesSent: iceCandidatesSent,
      reconnectAttempts: reconnectAttempts,
      peerFailures: peerFailures,
      streamRefreshes: streamRefreshes,
    );
  }
}

// ─── Snapshot (immutable) ─────────────────────────────────────────────────

/// Immutable point-in-time snapshot of a WebRTC session's telemetry.
class WebRtcSessionSnapshot {
  const WebRtcSessionSnapshot({
    required this.roomId,
    required this.startedAt,
    this.endedAt,
    required this.offersSent,
    required this.answersReceived,
    required this.iceCandidatesSent,
    required this.reconnectAttempts,
    required this.peerFailures,
    required this.streamRefreshes,
  });

  final String roomId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int offersSent;
  final int answersReceived;
  final int iceCandidatesSent;
  final int reconnectAttempts;
  final int peerFailures;
  final int streamRefreshes;

  Duration? get sessionDuration => endedAt?.difference(startedAt);
}



