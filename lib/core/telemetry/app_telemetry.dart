import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/room/room_state_contract.dart'
    show kRoomHealBurstCritical, kRoomHealBurstWarning;
import '../../services/analytics_service.dart';
import '../logger.dart';

class TelemetryEvent {
  const TelemetryEvent({
    required this.timestamp,
    required this.level,
    required this.domain,
    required this.action,
    required this.message,
    this.userId,
    this.roomId,
    this.result,
    this.metadata = const <String, Object?>{},
  });

  final DateTime timestamp;
  final String level;
  final String domain;
  final String action;
  final String message;
  final String? userId;
  final String? roomId;
  final String? result;
  final Map<String, Object?> metadata;
}

enum RoomHealthSeverity { healthy, warning, critical }

class RoomHealthAlert {
  const RoomHealthAlert({
    required this.code,
    required this.message,
    required this.severity,
  });

  final String code;
  final String message;
  final RoomHealthSeverity severity;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RoomHealthAlert &&
            other.code == code &&
            other.message == message &&
            other.severity == severity);
  }

  @override
  int get hashCode => Object.hash(code, message, severity);
}

class RoomHealthSnapshot {
  const RoomHealthSnapshot({
    this.severity = RoomHealthSeverity.healthy,
    this.score = 100,
    this.alerts = const <RoomHealthAlert>[],
    this.suppressedAlertCount = 0,
    this.suppressedAlertCodes = const <String>[],
    this.recentScores = const <int>[100],
    this.recoveryWindowActive = false,
    this.warningAlertCount = 0,
    this.criticalAlertCount = 0,
    this.duplicateJoinCount = 0,
    this.reconnectBurstCount = 0,
    this.firestoreErrorBurstCount = 0,
    this.healBurstCount = 0,
  });

  final RoomHealthSeverity severity;
  final int score;
  final List<RoomHealthAlert> alerts;
  final int suppressedAlertCount;
  final List<String> suppressedAlertCodes;
  final List<int> recentScores;
  final bool recoveryWindowActive;
  final int warningAlertCount;
  final int criticalAlertCount;
  final int duplicateJoinCount;
  final int reconnectBurstCount;
  final int firestoreErrorBurstCount;
  /// Number of self-healing corrections in the last 60 seconds.
  /// A sustained non-zero value means the system is repeatedly correcting
  /// an upstream inconsistency — investigate the root cause.
  final int healBurstCount;

  String get label {
    switch (severity) {
      case RoomHealthSeverity.healthy:
        return 'healthy';
      case RoomHealthSeverity.warning:
        return 'warning';
      case RoomHealthSeverity.critical:
        return 'critical';
    }
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is RoomHealthSnapshot &&
            other.severity == severity &&
            other.score == score &&
            other.suppressedAlertCount == suppressedAlertCount &&
            other.recoveryWindowActive == recoveryWindowActive &&
            other.warningAlertCount == warningAlertCount &&
            other.criticalAlertCount == criticalAlertCount &&
            other.duplicateJoinCount == duplicateJoinCount &&
            other.reconnectBurstCount == reconnectBurstCount &&
            other.firestoreErrorBurstCount == firestoreErrorBurstCount &&
            other.healBurstCount == healBurstCount &&
            listEquals(other.alerts, alerts) &&
            listEquals(other.suppressedAlertCodes, suppressedAlertCodes) &&
            listEquals(other.recentScores, recentScores));
  }

  @override
  int get hashCode => Object.hash(
    severity,
    score,
    suppressedAlertCount,
    recoveryWindowActive,
    warningAlertCount,
    criticalAlertCount,
    duplicateJoinCount,
    reconnectBurstCount,
    firestoreErrorBurstCount,
    healBurstCount,
    Object.hashAll(alerts),
    Object.hashAll(suppressedAlertCodes),
    Object.hashAll(recentScores),
  );
}

class AppTelemetryState {
  const AppTelemetryState({
    this.authUserId,
    this.authLoading = false,
    this.authError,
    this.roomId,
    this.joinedUserId,
    this.roomPhase,
    this.roomError,
    this.participantCount = 0,
    this.micMuted = true,
    this.videoEnabled = false,
    this.presenceStatus,
    this.roomPresenceStatus,
    this.globalPresenceOnline,
    this.inRoom,
    this.cameraStatus,
    this.callError,
    this.currentRtcUid,
    this.cameraMismatch = false,
    this.micMismatch = false,
    this.presenceMismatch = false,
    this.hostConflict = false,
    this.hostMissing = false,
    this.staleParticipantIds = const <String>{},
    this.activeListenersByKey = const <String, int>{},
    this.firestoreReadCount = 0,
    this.firestoreWriteCount = 0,
    this.firestoreSnapshotCount = 0,
    this.recentEvents = const <TelemetryEvent>[],
    this.roomHealth = const RoomHealthSnapshot(),
  });

  final String? authUserId;
  final bool authLoading;
  final String? authError;
  final String? roomId;
  final String? joinedUserId;
  final String? roomPhase;
  final String? roomError;
  final int participantCount;
  final bool micMuted;
  final bool videoEnabled;
  final String? presenceStatus;
  final String? roomPresenceStatus;
  final bool? globalPresenceOnline;
  final String? inRoom;
  final String? cameraStatus;
  final String? callError;
  final int? currentRtcUid;
  final bool cameraMismatch;
  final bool micMismatch;
  final bool presenceMismatch;
  final bool hostConflict;
  final bool hostMissing;
  final Set<String> staleParticipantIds;
  final Map<String, int> activeListenersByKey;
  final int firestoreReadCount;
  final int firestoreWriteCount;
  final int firestoreSnapshotCount;
  final List<TelemetryEvent> recentEvents;
  final RoomHealthSnapshot roomHealth;

  int get activeListenerCount =>
      activeListenersByKey.values.fold<int>(0, (sum, count) => sum + count);

  List<String> get duplicateListenerKeys => activeListenersByKey.entries
      .where((entry) => entry.value > 1)
      .map((entry) => entry.key)
      .toList(growable: false);

  AppTelemetryState copyWith({
    Object? authUserId = _unset,
    bool? authLoading,
    Object? authError = _unset,
    Object? roomId = _unset,
    Object? joinedUserId = _unset,
    Object? roomPhase = _unset,
    Object? roomError = _unset,
    int? participantCount,
    bool? micMuted,
    bool? videoEnabled,
    Object? presenceStatus = _unset,
    Object? roomPresenceStatus = _unset,
    Object? globalPresenceOnline = _unset,
    Object? inRoom = _unset,
    Object? cameraStatus = _unset,
    Object? callError = _unset,
    Object? currentRtcUid = _unset,
    bool? cameraMismatch,
    bool? micMismatch,
    bool? presenceMismatch,
    bool? hostConflict,
    bool? hostMissing,
    Set<String>? staleParticipantIds,
    Map<String, int>? activeListenersByKey,
    int? firestoreReadCount,
    int? firestoreWriteCount,
    int? firestoreSnapshotCount,
    List<TelemetryEvent>? recentEvents,
    RoomHealthSnapshot? roomHealth,
  }) {
    return AppTelemetryState(
      authUserId: identical(authUserId, _unset)
          ? this.authUserId
          : authUserId as String?,
      authLoading: authLoading ?? this.authLoading,
      authError: identical(authError, _unset)
          ? this.authError
          : authError as String?,
      roomId: identical(roomId, _unset) ? this.roomId : roomId as String?,
      joinedUserId: identical(joinedUserId, _unset)
          ? this.joinedUserId
          : joinedUserId as String?,
      roomPhase: identical(roomPhase, _unset)
          ? this.roomPhase
          : roomPhase as String?,
      roomError: identical(roomError, _unset)
          ? this.roomError
          : roomError as String?,
      participantCount: participantCount ?? this.participantCount,
      micMuted: micMuted ?? this.micMuted,
      videoEnabled: videoEnabled ?? this.videoEnabled,
      presenceStatus: identical(presenceStatus, _unset)
          ? this.presenceStatus
          : presenceStatus as String?,
      roomPresenceStatus: identical(roomPresenceStatus, _unset)
          ? this.roomPresenceStatus
          : roomPresenceStatus as String?,
      globalPresenceOnline: identical(globalPresenceOnline, _unset)
          ? this.globalPresenceOnline
          : globalPresenceOnline as bool?,
      inRoom: identical(inRoom, _unset) ? this.inRoom : inRoom as String?,
      cameraStatus: identical(cameraStatus, _unset)
          ? this.cameraStatus
          : cameraStatus as String?,
      callError: identical(callError, _unset)
          ? this.callError
          : callError as String?,
      currentRtcUid: identical(currentRtcUid, _unset)
          ? this.currentRtcUid
          : currentRtcUid as int?,
      cameraMismatch: cameraMismatch ?? this.cameraMismatch,
      micMismatch: micMismatch ?? this.micMismatch,
      presenceMismatch: presenceMismatch ?? this.presenceMismatch,
      hostConflict: hostConflict ?? this.hostConflict,
      hostMissing: hostMissing ?? this.hostMissing,
      staleParticipantIds: staleParticipantIds ?? this.staleParticipantIds,
      activeListenersByKey: activeListenersByKey ?? this.activeListenersByKey,
      firestoreReadCount: firestoreReadCount ?? this.firestoreReadCount,
      firestoreWriteCount: firestoreWriteCount ?? this.firestoreWriteCount,
      firestoreSnapshotCount:
          firestoreSnapshotCount ?? this.firestoreSnapshotCount,
      recentEvents: recentEvents ?? this.recentEvents,
      roomHealth: roomHealth ?? this.roomHealth,
    );
  }
}

const Object _unset = Object();

class AppTelemetry {
  AppTelemetry._();

  static const int _maxEvents = 40;
  static const Duration _roomHealthAlertCooldown = Duration(seconds: 20);
  static final AnalyticsService _analyticsService = AnalyticsService();
  static final Map<String, DateTime> _roomHealthAlertCooldownByCode =
      <String, DateTime>{};

  static final ValueNotifier<AppTelemetryState> notifier =
      ValueNotifier<AppTelemetryState>(const AppTelemetryState());

  static AppTelemetryState get state => notifier.value;

  static void reset() {
    notifier.value = const AppTelemetryState();
  }

  static void updateAuthState({
    String? userId,
    bool? isLoading,
    String? error,
  }) {
    final current = notifier.value;
    final next = current.copyWith(
      authUserId: userId,
      authLoading: isLoading,
      authError: error,
    );
    _emitIfChanged(current, next);
  }

  static void updateRoomState({
    String? roomId,
    String? joinedUserId,
    String? roomPhase,
    String? roomError,
    int? participantCount,
    bool? micMuted,
    bool? videoEnabled,
    String? presenceStatus,
    String? roomPresenceStatus,
    bool? globalPresenceOnline,
    String? inRoom,
    String? cameraStatus,
    String? callError,
    int? currentRtcUid,
    bool? cameraMismatch,
    bool? micMismatch,
    bool? presenceMismatch,
    bool? hostConflict,
    bool? hostMissing,
    Iterable<String>? staleParticipantIds,
  }) {
    final current = notifier.value;
    final nextStaleIds = staleParticipantIds == null
        ? current.staleParticipantIds
        : Set<String>.from(staleParticipantIds);
    final next = _withDerivedRoomHealth(
      current.copyWith(
        roomId: roomId,
        joinedUserId: joinedUserId,
        roomPhase: roomPhase,
        roomError: roomError,
        participantCount: participantCount,
        micMuted: micMuted,
        videoEnabled: videoEnabled,
        presenceStatus: presenceStatus,
        roomPresenceStatus: roomPresenceStatus,
        globalPresenceOnline: globalPresenceOnline,
        inRoom: inRoom,
        cameraStatus: cameraStatus,
        callError: callError,
        currentRtcUid: currentRtcUid,
        cameraMismatch: cameraMismatch,
        micMismatch: micMismatch,
        presenceMismatch: presenceMismatch,
        hostConflict: hostConflict,
        hostMissing: hostMissing,
        staleParticipantIds: nextStaleIds,
      ),
    );
    _emitIfChanged(current, next);
    _logRoomHealthTransition(
      previous: current.roomHealth,
      next: next.roomHealth,
      roomId: next.roomId,
      userId: next.joinedUserId,
    );

    final suppressedHealthCodes = next.roomHealth.suppressedAlertCodes.toSet();

    if (!current.cameraMismatch && next.cameraMismatch) {
      final isSuppressed = suppressedHealthCodes.contains('mic_desync');
      logAction(
        level: isSuppressed ? 'info' : 'warning',
        domain: 'room',
        action: isSuppressed ? 'camera_mismatch_suppressed' : 'camera_mismatch',
        message: isSuppressed
            ? 'Transient camera drift observed during reconnect recovery window.'
            : 'UI reports camera on while Firestore participant state is off.',
        userId: next.joinedUserId,
        roomId: next.roomId,
        result: isSuppressed ? 'suppressed' : 'mismatch',
      );
    }

    if (!current.micMismatch && next.micMismatch) {
      final isSuppressed = suppressedHealthCodes.contains('mic_desync');
      logAction(
        level: isSuppressed ? 'info' : 'warning',
        domain: 'room',
        action: isSuppressed
            ? 'mic_state_mismatch_suppressed'
            : 'mic_state_mismatch',
        message: isSuppressed
            ? 'Transient mic drift observed during reconnect recovery window.'
            : 'UI mic state drifted from the room authority state.',
        userId: next.joinedUserId,
        roomId: next.roomId,
        result: isSuppressed ? 'suppressed' : 'warning',
      );
    }

    if (!current.presenceMismatch && next.presenceMismatch) {
      final isSuppressed = suppressedHealthCodes.contains('ghost_leave_risk');
      logAction(
        level: isSuppressed ? 'info' : 'error',
        domain: 'presence',
        action: isSuppressed
            ? 'presence_mismatch_suppressed'
            : 'presence_mismatch',
        message: isSuppressed
            ? 'Transient presence drift observed during reconnect recovery window.'
            : 'Joined room state conflicts with presence document.',
        userId: next.joinedUserId,
        roomId: next.roomId,
        result: isSuppressed ? 'suppressed' : 'critical',
        metadata: <String, Object?>{
          'presenceStatus': next.presenceStatus,
          'inRoom': next.inRoom,
        },
      );
    }

    if (!current.hostConflict && next.hostConflict) {
      logAction(
        level: 'error',
        domain: 'room',
        action: 'multiple_hosts_detected',
        message: 'Multiple host claims were detected for the active room.',
        userId: next.joinedUserId,
        roomId: next.roomId,
        result: 'critical',
      );
    }

    if (!current.hostMissing && next.hostMissing) {
      logAction(
        level: 'warning',
        domain: 'room',
        action: 'no_active_host',
        message: 'The room is active but no authoritative host is present.',
        userId: next.joinedUserId,
        roomId: next.roomId,
        result: 'warning',
      );
    }

    if (!setEquals(current.staleParticipantIds, next.staleParticipantIds) &&
        next.staleParticipantIds.isNotEmpty) {
      final isSuppressed = suppressedHealthCodes.contains('stale_presence');
      logAction(
        level: isSuppressed ? 'info' : 'warning',
        domain: 'presence',
        action: isSuppressed
            ? 'stale_participants_suppressed'
            : 'stale_participants_detected',
        message: isSuppressed
            ? 'Stale participant drift observed during reconnect recovery window.'
            : 'One or more room participants missed heartbeat threshold.',
        userId: next.joinedUserId,
        roomId: next.roomId,
        result: isSuppressed ? 'suppressed' : 'stale',
        metadata: <String, Object?>{
          'staleParticipantIds': next.staleParticipantIds.toList(
            growable: false,
          ),
        },
      );
    }
  }

  static void clearRoomState() {
    final current = notifier.value;
    final next = _withDerivedRoomHealth(
      current.copyWith(
        roomId: null,
        joinedUserId: null,
        roomPhase: null,
        roomError: null,
        participantCount: 0,
        micMuted: true,
        videoEnabled: false,
        presenceStatus: null,
        roomPresenceStatus: null,
        globalPresenceOnline: null,
        inRoom: null,
        cameraStatus: null,
        callError: null,
        currentRtcUid: null,
        cameraMismatch: false,
        micMismatch: false,
        presenceMismatch: false,
        hostConflict: false,
        hostMissing: false,
        staleParticipantIds: const <String>{},
      ),
    );
    _emitIfChanged(current, next);
  }

  static void listenerStarted({
    required String key,
    required String query,
    String? roomId,
    String? userId,
  }) {
    final current = notifier.value;
    final listeners = Map<String, int>.from(current.activeListenersByKey);
    listeners[key] = (listeners[key] ?? 0) + 1;
    final next = current.copyWith(activeListenersByKey: listeners);
    _emitIfChanged(current, next);

    logAction(
      domain: 'firestore',
      action: 'listener_start',
      message: 'Firestore listener attached.',
      roomId: roomId,
      userId: userId,
      result: listeners[key].toString(),
      metadata: <String, Object?>{'key': key, 'query': query},
    );
  }

  static void listenerStopped({
    required String key,
    required String query,
    String? roomId,
    String? userId,
  }) {
    final current = notifier.value;
    final listeners = Map<String, int>.from(current.activeListenersByKey);
    final nextCount = (listeners[key] ?? 0) - 1;
    if (nextCount > 0) {
      listeners[key] = nextCount;
    } else {
      listeners.remove(key);
    }
    final next = current.copyWith(activeListenersByKey: listeners);
    _emitIfChanged(current, next);

    logAction(
      domain: 'firestore',
      action: 'listener_stop',
      message: 'Firestore listener detached.',
      roomId: roomId,
      userId: userId,
      result: nextCount > 0 ? nextCount.toString() : '0',
      metadata: <String, Object?>{'key': key, 'query': query},
    );
  }

  static void recordFirestoreRead({
    required String path,
    required String operation,
    String? roomId,
    String? userId,
  }) {
    final current = notifier.value;
    final next = current.copyWith(
      firestoreReadCount: current.firestoreReadCount + 1,
    );
    _emitIfChanged(current, next);
    logAction(
      domain: 'firestore',
      action: operation,
      message: 'Firestore read issued.',
      roomId: roomId,
      userId: userId,
      result: 'read',
      metadata: <String, Object?>{'path': path},
    );
  }

  static void recordFirestoreWrite({
    required String path,
    required String operation,
    String? roomId,
    String? userId,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    final current = notifier.value;
    final next = current.copyWith(
      firestoreWriteCount: current.firestoreWriteCount + 1,
    );
    _emitIfChanged(current, next);
    logAction(
      domain: 'firestore',
      action: operation,
      message: 'Firestore write issued.',
      roomId: roomId,
      userId: userId,
      result: 'write',
      metadata: <String, Object?>{'path': path, ...metadata},
    );
  }

  static void recordFirestoreSnapshot({
    required String key,
    required String query,
    required int count,
    String? roomId,
    String? userId,
  }) {
    final current = notifier.value;
    final next = current.copyWith(
      firestoreSnapshotCount: current.firestoreSnapshotCount + 1,
    );
    _emitIfChanged(current, next);
    logAction(
      domain: 'firestore',
      action: 'snapshot',
      message: 'Firestore snapshot triggered.',
      roomId: roomId,
      userId: userId,
      result: count.toString(),
      metadata: <String, Object?>{'key': key, 'query': query},
    );
  }

  static void recordFirestoreError({
    required String key,
    required String query,
    required Object error,
    StackTrace? stackTrace,
    String? roomId,
    String? userId,
  }) {
    logAction(
      level: 'error',
      domain: 'firestore',
      action: 'listener_error',
      message: 'Firestore listener failed.',
      roomId: roomId,
      userId: userId,
      result: 'error',
      metadata: <String, Object?>{'key': key, 'query': query},
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void logAction({
    String level = 'info',
    required String domain,
    required String action,
    required String message,
    String? userId,
    String? roomId,
    String? result,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    final event = TelemetryEvent(
      timestamp: DateTime.now(),
      level: level,
      domain: domain,
      action: action,
      message: message,
      userId: userId,
      roomId: roomId,
      result: result,
      metadata: Map<String, Object?>.from(metadata),
    );

    final current = notifier.value;
    final events = <TelemetryEvent>[event, ...current.recentEvents];
    if (events.length > _maxEvents) {
      events.removeRange(_maxEvents, events.length);
    }
    notifier.value = _withDerivedRoomHealth(
      current.copyWith(recentEvents: events),
    );

    final buffer = StringBuffer()
      ..write('[')
      ..write(event.timestamp.toIso8601String())
      ..write('] ')
      ..write('[')
      ..write(event.domain.toUpperCase())
      ..write(' ')
      ..write(event.action.toUpperCase())
      ..write('] ')
      ..write(message);
    if (userId != null && userId.isNotEmpty) {
      buffer.write(' userId=');
      buffer.write(userId);
    }
    if (roomId != null && roomId.isNotEmpty) {
      buffer.write(' roomId=');
      buffer.write(roomId);
    }
    if (result != null && result.isNotEmpty) {
      buffer.write(' result=');
      buffer.write(result);
    }
    if (metadata.isNotEmpty) {
      metadata.forEach((key, value) {
        buffer.write(' ');
        buffer.write(key);
        buffer.write('=');
        buffer.write(value);
      });
    }
    final formatted = buffer.toString();

    switch (level) {
      case 'error':
        Logger.error(formatted, error: error, stackTrace: stackTrace);
        break;
      case 'warning':
        Logger.warning(formatted, error: error, stackTrace: stackTrace);
        break;
      default:
        Logger.info(formatted, error: error, stackTrace: stackTrace);
        break;
    }

    if (_shouldForwardToAnalytics(event)) {
      unawaited(
        _analyticsService.logEvent(
          _analyticsEventNameFor(event),
          params: _analyticsParamsFor(event),
        ),
      );
    }
  }

  static bool _shouldForwardToAnalytics(TelemetryEvent event) {
    if (event.domain == 'firestore') {
      return event.level == 'error';
    }
    return const <String>{
      'room',
      'auth',
      'presence',
      'schema',
      'moderation',
      'routing',
      'ops',
      'messaging',
    }.contains(event.domain);
  }

  static String _analyticsEventNameFor(TelemetryEvent event) {
    final raw = '${event.domain}_${event.action}'.toLowerCase();
    final normalized = raw
        .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    final candidate = normalized.isEmpty
        ? 'mixvy_event'
        : (RegExp(r'^[a-z]').hasMatch(normalized)
              ? normalized
              : 'e_$normalized');
    return candidate.length <= 40 ? candidate : candidate.substring(0, 40);
  }

  static Map<String, Object> _analyticsParamsFor(TelemetryEvent event) {
    final params = <String, Object>{
      'level': event.level,
      if (event.result?.isNotEmpty == true) 'result': event.result!,
      if (event.roomId?.isNotEmpty == true) 'room_id': event.roomId!,
      'has_error': event.level == 'error',
    };

    for (final entry in event.metadata.entries) {
      if (params.length >= 10) {
        break;
      }
      final key = entry.key
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9_]'), '_')
          .replaceAll(RegExp(r'_+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      if (key.isEmpty || params.containsKey(key)) {
        continue;
      }
      final value = entry.value;
      if (value is bool) {
        params[key] = value;
      } else if (value is int) {
        params[key] = value;
      } else if (value is double) {
        params[key] = value;
      } else if (value != null) {
        final asString = value.toString();
        if (asString.isNotEmpty) {
          params[key] = asString.length <= 100
              ? asString
              : asString.substring(0, 100);
        }
      }
    }

    return params;
  }

  static void logEnforcementEvent({
    String level = 'info',
    required String action,
    required String message,
    String? userId,
    String? roomId,
    String? result,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    logAction(
      level: level,
      domain: 'schema',
      action: action,
      message: message,
      userId: userId,
      roomId: roomId,
      result: result,
      metadata: <String, Object?>{'eventCategory': 'enforcement', ...metadata},
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void logMigrationEvent({
    String level = 'info',
    required String domain,
    required String action,
    required String message,
    String? userId,
    String? roomId,
    String? result,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    logAction(
      level: level,
      domain: domain,
      action: action,
      message: message,
      userId: userId,
      roomId: roomId,
      result: result,
      metadata: <String, Object?>{'eventCategory': 'migration', ...metadata},
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void logParityEvent({
    String level = 'info',
    required String domain,
    required String action,
    required String message,
    String? userId,
    String? roomId,
    String? result,
    Map<String, Object?> metadata = const <String, Object?>{},
    Object? error,
    StackTrace? stackTrace,
  }) {
    logAction(
      level: level,
      domain: domain,
      action: action,
      message: message,
      userId: userId,
      roomId: roomId,
      result: result,
      metadata: <String, Object?>{'eventCategory': 'parity', ...metadata},
      error: error,
      stackTrace: stackTrace,
    );
  }

  static AppTelemetryState _withDerivedRoomHealth(AppTelemetryState state) {
    return state.copyWith(roomHealth: _buildRoomHealthSnapshot(state));
  }

  static RoomHealthSnapshot _buildRoomHealthSnapshot(AppTelemetryState state) {
    final alerts = <RoomHealthAlert>[];
    final suppressedAlertCodes = <String>[];
    var score = 100;

    final duplicateJoinCount = _countRecentEvents(
      state.recentEvents,
      window: const Duration(seconds: 15),
      predicate: (event) =>
          event.domain == 'room' &&
          event.action == 'join' &&
          event.result == 'start' &&
          event.userId == state.joinedUserId &&
          event.roomId == state.roomId,
    );
    final reconnectBurstCount = _countRecentEvents(
      state.recentEvents,
      window: const Duration(seconds: 15),
      predicate: (event) =>
          event.domain == 'room' &&
          event.action == 'live_trace' &&
          event.message.contains('reconnect attempt='),
    );
    final firestoreErrorBurstCount = _countRecentEvents(
      state.recentEvents,
      window: const Duration(seconds: 30),
      predicate: (event) =>
          event.domain == 'firestore' &&
          (event.action == 'listener_error' || event.level == 'error'),
    );
    // Count self-healing corrections over the last 60 seconds.
    // A spike here means the upstream data source is chronically inconsistent.
    final healBurstCount = _countRecentEvents(
      state.recentEvents,
      window: const Duration(seconds: 60),
      predicate: (event) =>
          event.domain == 'room' &&
          (event.action == 'self_heal_ghost_speakers' ||
              event.action == 'self_heal_host_role' ||
              event.action == 'pending_role_expired'),
    );

    final inRecoveryWindow =
        state.roomPhase == 'joining' ||
        reconnectBurstCount > 0 ||
        (state.roomError?.toLowerCase().contains('reconnect') ?? false) ||
        (state.callError?.toLowerCase().contains('reconnect') ?? false);

    void addAlert({
      required String code,
      required String message,
      required RoomHealthSeverity severity,
      required int penalty,
      bool suppressDuringRecovery = false,
      int suppressedPenalty = 3,
    }) {
      if (alerts.any((alert) => alert.code == code) ||
          suppressedAlertCodes.contains(code)) {
        return;
      }
      if (suppressDuringRecovery && inRecoveryWindow) {
        suppressedAlertCodes.add(code);
        score -= suppressedPenalty;
        return;
      }
      alerts.add(
        RoomHealthAlert(code: code, message: message, severity: severity),
      );
      score -= penalty;
    }

    final roomMismatch =
        state.roomPhase == 'joined' &&
        state.roomId != null &&
        state.roomId!.trim().isNotEmpty &&
        state.inRoom != null &&
        state.inRoom!.trim().isNotEmpty &&
        state.inRoom!.trim() != state.roomId!.trim();

    if (state.presenceMismatch || roomMismatch) {
      addAlert(
        code: 'ghost_leave_risk',
        message: 'Presence and room authority are drifting out of sync.',
        severity: RoomHealthSeverity.critical,
        penalty: 25,
        suppressDuringRecovery: true,
      );
    }

    if (duplicateJoinCount >= 2) {
      addAlert(
        code: 'duplicate_join_storm',
        message: 'Repeated join calls were detected for the same session.',
        severity: duplicateJoinCount >= 3
            ? RoomHealthSeverity.critical
            : RoomHealthSeverity.warning,
        penalty: duplicateJoinCount >= 3 ? 25 : 15,
      );
    }

    if (state.duplicateListenerKeys.isNotEmpty) {
      addAlert(
        code: 'zombie_listeners',
        message: 'Duplicate Firestore listeners are still attached.',
        severity: RoomHealthSeverity.warning,
        penalty: 15,
      );
    }

    if (firestoreErrorBurstCount >= 3) {
      addAlert(
        code: 'stream_reset_loop',
        message: 'Firestore listener failures are looping too quickly.',
        severity: RoomHealthSeverity.critical,
        penalty: 25,
      );
    }

    if (state.cameraMismatch || state.micMismatch) {
      addAlert(
        code: 'mic_desync',
        message: 'Local media UI is out of sync with room authority.',
        severity: state.micMismatch
            ? RoomHealthSeverity.critical
            : RoomHealthSeverity.warning,
        penalty: state.micMismatch ? 20 : 10,
        suppressDuringRecovery: true,
      );
    }

    if (state.hostConflict) {
      addAlert(
        code: 'host_split_brain',
        message: 'More than one user is claiming host authority.',
        severity: RoomHealthSeverity.critical,
        penalty: 30,
      );
    }

    if (state.hostMissing) {
      addAlert(
        code: 'host_missing',
        message: 'The room is active but has no authoritative host.',
        severity: RoomHealthSeverity.warning,
        penalty: 20,
      );
    }

    if (reconnectBurstCount >= 3) {
      addAlert(
        code: 'reconnect_loop_thrash',
        message: 'Reconnect attempts are thrashing the active session.',
        severity: RoomHealthSeverity.critical,
        penalty: 25,
      );
    }

    if (healBurstCount >= kRoomHealBurstWarning) {
      addAlert(
        code: 'self_heal_spike',
        message:
            'The room engine is repeatedly correcting state inconsistencies '
            '(${healBurstCount}x in 60s). '
            'Investigate upstream Firestore write or ordering issues.',
        severity:
            healBurstCount >= kRoomHealBurstCritical
                ? RoomHealthSeverity.critical
                : RoomHealthSeverity.warning,
        penalty: healBurstCount >= kRoomHealBurstCritical ? 20 : 10,
        suppressDuringRecovery: true,
      );
    }

    if (state.staleParticipantIds.isNotEmpty) {
      addAlert(
        code: 'stale_presence',
        message: 'One or more participants missed the heartbeat window.',
        severity: RoomHealthSeverity.warning,
        penalty: 10,
        suppressDuringRecovery: true,
      );
    }

    final boundedScore = score.clamp(0, 100);
    final warningAlertCount = alerts
        .where((alert) => alert.severity == RoomHealthSeverity.warning)
        .length;
    final criticalAlertCount = alerts
        .where((alert) => alert.severity == RoomHealthSeverity.critical)
        .length;
    final severity = criticalAlertCount > 0
        ? RoomHealthSeverity.critical
        : (warningAlertCount > 0 || suppressedAlertCodes.isNotEmpty)
        ? RoomHealthSeverity.warning
        : RoomHealthSeverity.healthy;

    final recentScores = <int>[
      ...state.roomHealth.recentScores,
      if (state.roomHealth.recentScores.isEmpty ||
          state.roomHealth.recentScores.last != boundedScore)
        boundedScore,
    ];
    if (recentScores.length > 12) {
      recentScores.removeRange(0, recentScores.length - 12);
    }

    return RoomHealthSnapshot(
      severity: severity,
      score: boundedScore,
      alerts: List<RoomHealthAlert>.unmodifiable(alerts),
      suppressedAlertCount: suppressedAlertCodes.length,
      suppressedAlertCodes: List<String>.unmodifiable(suppressedAlertCodes),
      recentScores: List<int>.unmodifiable(recentScores),
      recoveryWindowActive: inRecoveryWindow,
      warningAlertCount: warningAlertCount,
      criticalAlertCount: criticalAlertCount,
      duplicateJoinCount: duplicateJoinCount,
      reconnectBurstCount: reconnectBurstCount,
      firestoreErrorBurstCount: firestoreErrorBurstCount,
      healBurstCount: healBurstCount,
    );
  }

  static void _logRoomHealthTransition({
    required RoomHealthSnapshot previous,
    required RoomHealthSnapshot next,
    String? roomId,
    String? userId,
  }) {
    if (previous == next) {
      return;
    }

    if (previous.severity != next.severity) {
      logAction(
        level: next.severity == RoomHealthSeverity.critical
            ? 'error'
            : next.severity == RoomHealthSeverity.warning
            ? 'warning'
            : 'info',
        domain: 'room',
        action: 'health_status_changed',
        message: 'Room health changed to ${next.label}.',
        roomId: roomId,
        userId: userId,
        result: next.label,
        metadata: <String, Object?>{
          'score': next.score,
          'suppressedAlertCount': next.suppressedAlertCount,
          'warningAlertCount': next.warningAlertCount,
          'criticalAlertCount': next.criticalAlertCount,
        },
      );
    }

    final previousCodes = previous.alerts.map((alert) => alert.code).toSet();
    for (final alert in next.alerts) {
      if (previousCodes.contains(alert.code) ||
          !_canEmitHealthAlert(alert.code)) {
        continue;
      }
      logAction(
        level: alert.severity == RoomHealthSeverity.critical
            ? 'error'
            : 'warning',
        domain: 'room',
        action: 'health_alert',
        message: alert.message,
        roomId: roomId,
        userId: userId,
        result: alert.severity.name,
        metadata: <String, Object?>{
          'alertCode': alert.code,
          'score': next.score,
        },
      );
    }
  }

  static bool _canEmitHealthAlert(String code) {
    final now = DateTime.now();
    final lastEmittedAt = _roomHealthAlertCooldownByCode[code];
    if (lastEmittedAt != null &&
        now.difference(lastEmittedAt) < _roomHealthAlertCooldown) {
      return false;
    }
    _roomHealthAlertCooldownByCode[code] = now;
    return true;
  }

  static int _countRecentEvents(
    List<TelemetryEvent> events, {
    required Duration window,
    required bool Function(TelemetryEvent event) predicate,
  }) {
    final threshold = DateTime.now().subtract(window);
    return events
        .where((event) => event.timestamp.isAfter(threshold))
        .where(predicate)
        .length;
  }

  static void _emitIfChanged(
    AppTelemetryState current,
    AppTelemetryState next,
  ) {
    if (_sameState(current, next)) {
      return;
    }
    notifier.value = next;
  }

  static bool _sameState(AppTelemetryState left, AppTelemetryState right) {
    return left.authUserId == right.authUserId &&
        left.authLoading == right.authLoading &&
        left.authError == right.authError &&
        left.roomId == right.roomId &&
        left.joinedUserId == right.joinedUserId &&
        left.roomPhase == right.roomPhase &&
        left.roomError == right.roomError &&
        left.participantCount == right.participantCount &&
        left.micMuted == right.micMuted &&
        left.videoEnabled == right.videoEnabled &&
        left.presenceStatus == right.presenceStatus &&
        left.roomPresenceStatus == right.roomPresenceStatus &&
        left.globalPresenceOnline == right.globalPresenceOnline &&
        left.inRoom == right.inRoom &&
        left.cameraStatus == right.cameraStatus &&
        left.callError == right.callError &&
        left.currentRtcUid == right.currentRtcUid &&
        left.cameraMismatch == right.cameraMismatch &&
        left.micMismatch == right.micMismatch &&
        left.presenceMismatch == right.presenceMismatch &&
        left.hostConflict == right.hostConflict &&
        left.hostMissing == right.hostMissing &&
        setEquals(left.staleParticipantIds, right.staleParticipantIds) &&
        mapEquals(left.activeListenersByKey, right.activeListenersByKey) &&
        left.firestoreReadCount == right.firestoreReadCount &&
        left.firestoreWriteCount == right.firestoreWriteCount &&
        left.firestoreSnapshotCount == right.firestoreSnapshotCount &&
        listEquals(left.recentEvents, right.recentEvents) &&
        left.roomHealth == right.roomHealth;
  }
}
