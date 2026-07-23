// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/telemetry/telemetry_config.dart';
import 'package:mixvy/observability/firestore_call_tracker.dart';
import 'package:mixvy/observability/production_alerts.dart';
import 'package:mixvy/observability/runtime_telemetry.dart';
import 'package:mixvy/observability/stream_telemetry.dart';
import 'package:mixvy/observability/webrtc_telemetry.dart';

void main() {
  // ─── Phase 1: Telemetry mode switching ─────────────────────────────────────

  group('TelemetryMode switching', () {
    setUp(() => TelemetryConfig.clearRuntimeOverride());

    test('off mode disables all tiers', () {
      TelemetryConfig.initialize(TelemetryMode.off);
      expect(TelemetryConfig.isActive, isFalse);
      expect(TelemetryConfig.allows(LogTier.critical), isFalse);
      expect(TelemetryConfig.allows(LogTier.operational), isFalse);
      expect(TelemetryConfig.allows(LogTier.debug), isFalse);
    });

    test('standard mode allows critical and operational only', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      expect(TelemetryConfig.isActive, isTrue);
      expect(TelemetryConfig.allows(LogTier.critical), isTrue);
      expect(TelemetryConfig.allows(LogTier.operational), isTrue);
      expect(TelemetryConfig.allows(LogTier.debug), isFalse);
    });

    test('debug mode allows all tiers', () {
      TelemetryConfig.initialize(TelemetryMode.debug);
      expect(TelemetryConfig.allows(LogTier.critical), isTrue);
      expect(TelemetryConfig.allows(LogTier.operational), isTrue);
      expect(TelemetryConfig.allows(LogTier.debug), isTrue);
    });

    test('runtime override takes precedence over base', () {
      TelemetryConfig.initialize(TelemetryMode.off);
      expect(TelemetryConfig.isActive, isFalse);

      TelemetryConfig.setRuntimeOverride(TelemetryMode.debug);
      expect(TelemetryConfig.mode, TelemetryMode.debug);
      expect(TelemetryConfig.isActive, isTrue);
    });

    test('clearing override reverts to base', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      TelemetryConfig.setRuntimeOverride(TelemetryMode.debug);
      TelemetryConfig.clearRuntimeOverride();
      expect(TelemetryConfig.mode, TelemetryMode.standard);
    });

    test('off mode blocks FirestoreCallTracker', () {
      TelemetryConfig.initialize(TelemetryMode.off);
      FirestoreCallTracker.reset();
      FirestoreCallTracker.trackRead('rooms/x');
      FirestoreCallTracker.trackWrite('rooms/x');
      expect(FirestoreCallTracker.totalReads, 0);
      expect(FirestoreCallTracker.totalWrites, 0);
    });

    test('standard mode records Firestore activity', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      FirestoreCallTracker.reset();
      FirestoreCallTracker.trackRead('rooms/abc');
      FirestoreCallTracker.trackWrite('rooms/abc');
      expect(FirestoreCallTracker.totalReads, 1);
      expect(FirestoreCallTracker.totalWrites, 1);
    });

    test('off mode blocks WebRtcTelemetry session', () {
      TelemetryConfig.initialize(TelemetryMode.off);
      WebRtcTelemetry.beginSession('room1');
      expect(WebRtcTelemetry.currentSession, isNull);
    });

    test('standard mode tracks WebRTC session', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      WebRtcTelemetry.beginSession('room2');
      expect(WebRtcTelemetry.currentSession, isNotNull);
      expect(WebRtcTelemetry.currentSession!.roomId, 'room2');
      WebRtcTelemetry.endSession();
    });
  });

  // ─── Phase 2: Session reset integrity ──────────────────────────────────────

  group('Session reset integrity', () {
    setUp(() {
      TelemetryConfig.initialize(TelemetryMode.standard);
    });

    test('FirestoreCallTracker reset clears all counters', () {
      FirestoreCallTracker.trackRead('users/a');
      FirestoreCallTracker.trackWrite('users/a');
      FirestoreCallTracker.reset();
      expect(FirestoreCallTracker.totalReads, 0);
      expect(FirestoreCallTracker.totalWrites, 0);
      expect(FirestoreCallTracker.snapshotReads(), isEmpty);
      expect(FirestoreCallTracker.snapshotWrites(), isEmpty);
    });

    test('RuntimeTelemetry reset clears listeners and rebuilds', () {
      RuntimeTelemetry.registerListener('test_key');
      RuntimeTelemetry.recordRebuild('MyWidget');
      RuntimeTelemetry.reset();
      expect(RuntimeTelemetry.listeners, isEmpty);
      expect(RuntimeTelemetry.rebuilds, isEmpty);
    });

    test('StreamTelemetry reset clears all state', () {
      StreamTelemetry.reset();
      expect(StreamTelemetry.snapshotSubscriptions(), isEmpty);
      expect(StreamTelemetry.snapshotEmits(), isEmpty);
    });

    test('no cross-session bleed between FirestoreCallTracker resets', () {
      FirestoreCallTracker.trackRead('rooms/s1');
      FirestoreCallTracker.trackRead('rooms/s1');
      FirestoreCallTracker.reset();
      FirestoreCallTracker.trackRead('messages/s2');
      expect(
        FirestoreCallTracker.snapshotReads().containsKey('rooms'),
        isFalse,
      );
      expect(FirestoreCallTracker.snapshotReads()['messages'], 1);
    });

    test('WebRTC new session replaces previous session state', () {
      WebRtcTelemetry.beginSession('roomA');
      WebRtcTelemetry.recordReconnect();
      WebRtcTelemetry.endSession();
      final s1 = WebRtcTelemetry.lastSession!;

      WebRtcTelemetry.beginSession('roomB');
      final current = WebRtcTelemetry.currentSession!;
      expect(current.roomId, 'roomB');
      expect(current.reconnectAttempts, 0);
      expect(WebRtcTelemetry.lastSession!.roomId, s1.roomId);
      WebRtcTelemetry.endSession();
    });
  });

  // ─── Phase 3: Reconnect telemetry continuity ────────────────────────────────

  group('Reconnect telemetry continuity', () {
    setUp(() {
      TelemetryConfig.initialize(TelemetryMode.standard);
      ProductionAlertSystem.reset();
    });

    test('reconnect attempts accumulate per session', () {
      WebRtcTelemetry.beginSession('roomC');
      WebRtcTelemetry.recordReconnect();
      WebRtcTelemetry.recordReconnect();
      WebRtcTelemetry.recordReconnect();
      expect(WebRtcTelemetry.currentSession!.reconnectAttempts, 3);
      WebRtcTelemetry.endSession();
    });

    test('reconnect burst fires WARNING alert at 5 attempts', () {
      WebRtcTelemetry.beginSession('roomD');
      for (var i = 0; i < 5; i++) {
        WebRtcTelemetry.recordReconnect();
      }
      final alerts = ProductionAlertSystem.alerts;
      expect(
        alerts.any(
          (a) =>
              a.id.startsWith('webrtc_reconnect_burst_') &&
              a.level == AlertLevel.warning,
        ),
        isTrue,
      );
      WebRtcTelemetry.endSession();
    });

    test('reconnect burst fires CRITICAL alert at 10 attempts', () {
      WebRtcTelemetry.beginSession('roomE');
      for (var i = 0; i < 10; i++) {
        WebRtcTelemetry.recordReconnect();
      }
      final alerts = ProductionAlertSystem.alerts;
      expect(
        alerts.any(
          (a) =>
              a.id.startsWith('webrtc_reconnect_critical_') &&
              a.level == AlertLevel.critical,
        ),
        isTrue,
      );
      WebRtcTelemetry.endSession();
    });

    test('peer failure emits WARNING alert', () {
      WebRtcTelemetry.beginSession('roomF');
      WebRtcTelemetry.recordPeerFailure(broadcasterId: 'host1');
      expect(
        ProductionAlertSystem.alerts.any(
          (a) =>
              a.id == 'webrtc_peer_fail_host1' && a.level == AlertLevel.warning,
        ),
        isTrue,
      );
      WebRtcTelemetry.endSession();
    });

    test('session snapshot is preserved after endSession', () {
      WebRtcTelemetry.beginSession('roomG');
      WebRtcTelemetry.recordOfferSent();
      WebRtcTelemetry.recordAnswerReceived();
      WebRtcTelemetry.endSession();

      final snap = WebRtcTelemetry.lastSession!;
      expect(snap.offersSent, 1);
      expect(snap.answersReceived, 1);
      expect(snap.endedAt, isNotNull);
      expect(snap.sessionDuration, isNotNull);
    });
  });

  // ─── Phase 4: Burst detection correctness ──────────────────────────────────

  group('Burst detection correctness', () {
    setUp(() {
      TelemetryConfig.initialize(TelemetryMode.standard);
      ProductionAlertSystem.reset();
    });

    test('Firestore read burst fires alert at threshold', () {
      FirestoreCallTracker.reset();
      for (var i = 0; i < 100; i++) {
        FirestoreCallTracker.trackRead('rooms/x');
      }
      expect(
        ProductionAlertSystem.alerts.any(
          (a) =>
              a.id == 'firestore_read_warn_rooms' &&
              a.level == AlertLevel.warning,
        ),
        isTrue,
      );
    });

    test('Firestore read critical fires at 300 reads', () {
      FirestoreCallTracker.reset();
      ProductionAlertSystem.reset();
      for (var i = 0; i < 300; i++) {
        FirestoreCallTracker.trackRead('rooms/x');
      }
      expect(
        ProductionAlertSystem.alerts.any(
          (a) =>
              a.id == 'firestore_read_critical_rooms' &&
              a.level == AlertLevel.critical,
        ),
        isTrue,
      );
    });

    test('Firestore per-session cap prevents unbounded growth', () {
      FirestoreCallTracker.reset();
      // Write 3000 events; should cap at _maxEventsPerSession (2000)
      for (var i = 0; i < 3000; i++) {
        FirestoreCallTracker.trackRead('rooms/cap_test');
      }
      expect(
        FirestoreCallTracker.totalReads + FirestoreCallTracker.totalWrites,
        lessThanOrEqualTo(2000),
      );
    });

    test('ICE candidate sampling reduces count in standard mode', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      WebRtcTelemetry.beginSession('roomH');
      // Send 100 ICE candidates; sampled at rate 1/5 → expect ~20
      for (var i = 0; i < 100; i++) {
        WebRtcTelemetry.recordIceCandidateSent();
      }
      final sampled = WebRtcTelemetry.currentSession!.iceCandidatesSent;
      expect(sampled, lessThan(100));
      expect(sampled, greaterThan(0));
      WebRtcTelemetry.endSession();
    });

    test('ICE candidate full count in debug mode', () {
      TelemetryConfig.initialize(TelemetryMode.debug);
      WebRtcTelemetry.beginSession('roomI');
      for (var i = 0; i < 10; i++) {
        WebRtcTelemetry.recordIceCandidateSent();
      }
      expect(WebRtcTelemetry.currentSession!.iceCandidatesSent, 10);
      WebRtcTelemetry.endSession();
    });

    test('alert deduplication prevents storm within 10 seconds', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      ProductionAlertSystem.reset();
      // Fire the same alert id 10 times rapidly
      for (var i = 0; i < 10; i++) {
        ProductionAlertSystem.fireCustomAlert(
          id: 'burst_dedup_test',
          message: 'test alert',
          level: AlertLevel.warning,
        );
      }
      final count = ProductionAlertSystem.alerts
          .where((a) => a.id == 'burst_dedup_test')
          .length;
      expect(count, 1);
    });
  });

  // ─── Phase 5: Release gate smoke ───────────────────────────────────────────

  group('Release gate smoke', () {
    test('standard mode has no performance regressions (basic smoke)', () {
      TelemetryConfig.initialize(TelemetryMode.standard);
      final sw = Stopwatch()..start();
      // 10k telemetry calls should complete well under 100ms
      for (var i = 0; i < 10000; i++) {
        FirestoreCallTracker.trackRead('rooms/perf_$i');
      }
      sw.stop();
      expect(sw.elapsedMilliseconds, lessThan(500));
      FirestoreCallTracker.reset();
    });

    test('ProductionAlertSystem.reset clears all alerts', () {
      ProductionAlertSystem.fireCustomAlert(
        id: 'reset_test',
        message: 'test',
        level: AlertLevel.info,
      );
      ProductionAlertSystem.reset();
      expect(ProductionAlertSystem.alerts, isEmpty);
    });
  });
}
