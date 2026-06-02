import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/events/app_event_bus.dart';
import '../../core/events/event_inspector.dart';
import '../../core/telemetry/app_telemetry.dart';
import '../../presentation/providers/presence_provider.dart';

class AppDebugOverlay extends ConsumerStatefulWidget {
  const AppDebugOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppDebugOverlay> createState() => _AppDebugOverlayState();
}

class _AppDebugOverlayState extends ConsumerState<AppDebugOverlay> {
  bool _isVisible = false;
  int _secretTapCount = 0;
  Timer? _secretTapTimer;
  Timer? _lastSeenTicker;
  StreamSubscription<Map<String, dynamic>?>? _firestorePresenceSub;
  StreamSubscription<Map<dynamic, dynamic>>? _rtdbSessionsSub;

  String? _watchedUserId;
  Map<String, dynamic>? _firestorePresence;

  int _rtdbSessionCount = 0;
  bool _rtdbAnyOnline = false;
  bool _rtdbAnyCamOn = false;
  bool _rtdbAnyMicOn = false;
  String? _rtdbAnyInRoom;
  int? _latestRtdbLastSeenMs;

  DateTime? _lastRtdbObservedAt;
  DateTime? _lastFirestoreObservedAt;
  int? _lastFirestoreRtdbUpdatedAtMs;
  int? _rtdbToFirestoreDelayMs;
  int? _firestoreToUiDelayMs;
  int _selectedTimelineIndex = 1;
  bool _groupBusTimelineBySession = true;

  @override
  void dispose() {
    _secretTapTimer?.cancel();
    _stopPresenceDebugWatch(resetData: false);
    super.dispose();
  }

  void _toggleOverlay() {
    final nextVisible = !_isVisible;
    setState(() => _isVisible = nextVisible);
    if (nextVisible) {
      _startPresenceDebugWatch();
    } else {
      _stopPresenceDebugWatch(resetData: false);
    }
  }

  void _startPresenceDebugWatch() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) {
      _stopPresenceDebugWatch(resetData: true);
      return;
    }
    if (_watchedUserId == uid &&
        (_firestorePresenceSub != null || _rtdbSessionsSub != null)) {
      return;
    }

    _stopPresenceDebugWatch(resetData: true);
    _watchedUserId = uid;

    _lastSeenTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {});
      }
    });

    _firestorePresenceSub = ref.read(debugFirestorePresenceWatch(uid)).listen((
      data,
    ) {
      final observedAt = DateTime.now();
      final currentUpdatedAtMs = _asEpochMillis(data?['rtdbUpdatedAt']);
      final shouldUpdateRtdbDelay = currentUpdatedAtMs != null &&
          currentUpdatedAtMs != _lastFirestoreRtdbUpdatedAtMs;
      final rtdbDelay = shouldUpdateRtdbDelay && _lastRtdbObservedAt != null
          ? observedAt.difference(_lastRtdbObservedAt!).inMilliseconds
          : _rtdbToFirestoreDelayMs;

      if (!mounted) {
        return;
      }

      setState(() {
        _firestorePresence = data;
        _lastFirestoreObservedAt = observedAt;
        _lastFirestoreRtdbUpdatedAtMs = currentUpdatedAtMs;
        _rtdbToFirestoreDelayMs = rtdbDelay;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        final base = _lastFirestoreObservedAt;
        if (base == null) {
          return;
        }
        setState(() {
          _firestoreToUiDelayMs =
              DateTime.now().difference(base).inMilliseconds;
        });
      });
    });

    _rtdbSessionsSub = ref.read(debugRtdbSessionsWatch(uid)).listen((raw) {
      final observedAt = DateTime.now();
      var sessionCount = 0;
      var anyOnline = false;
      var anyCamOn = false;
      var anyMicOn = false;
      String? anyInRoom;
      int? latestSeen;

      // raw is always Map<dynamic,dynamic> per the provider's return type.
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is! Map) {
          continue;
        }
        sessionCount += 1;
        final online = value['online'] == true;
        if (online) {
          anyOnline = true;
        }
        if (value['cam_on'] == true) {
          anyCamOn = true;
        }
        if (value['mic_on'] == true) {
          anyMicOn = true;
        }
        final inRoomValue = value['in_room'];
        if (anyInRoom == null &&
            inRoomValue is String &&
            inRoomValue.trim().isNotEmpty) {
          anyInRoom = inRoomValue.trim();
        }
        final lastSeenRaw = value['last_seen'];
        if (lastSeenRaw is int) {
          if (latestSeen == null || lastSeenRaw > latestSeen) {
            latestSeen = lastSeenRaw;
          }
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _lastRtdbObservedAt = observedAt;
        _rtdbSessionCount = sessionCount;
        _rtdbAnyOnline = anyOnline;
        _rtdbAnyCamOn = anyCamOn;
        _rtdbAnyMicOn = anyMicOn;
        _rtdbAnyInRoom = anyInRoom;
        _latestRtdbLastSeenMs = latestSeen;
      });
    });
  }

  void _stopPresenceDebugWatch({required bool resetData}) {
    _lastSeenTicker?.cancel();
    _lastSeenTicker = null;
    _firestorePresenceSub?.cancel();
    _firestorePresenceSub = null;
    _rtdbSessionsSub?.cancel();
    _rtdbSessionsSub = null;
    _watchedUserId = null;
    if (!resetData) {
      return;
    }
    _firestorePresence = null;
    _rtdbSessionCount = 0;
    _rtdbAnyOnline = false;
    _rtdbAnyCamOn = false;
    _rtdbAnyMicOn = false;
    _rtdbAnyInRoom = null;
    _latestRtdbLastSeenMs = null;
    _lastRtdbObservedAt = null;
    _lastFirestoreObservedAt = null;
    _lastFirestoreRtdbUpdatedAtMs = null;
    _rtdbToFirestoreDelayMs = null;
    _firestoreToUiDelayMs = null;
  }

  String _formatLastSeenAge() {
    final millis = _latestRtdbLastSeenMs;
    if (millis == null || millis <= 0) {
      return '-';
    }
    final diff = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(millis),
    );
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    }
    return '${diff.inMinutes}m ${diff.inSeconds % 60}s ago';
  }

  bool _asBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized == 'true' || normalized == '1';
    }
    return false;
  }

  String _asTrimmedString(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    return '';
  }

  int? _asEpochMillis(dynamic value) {
    if (value is Timestamp) {
      return value.millisecondsSinceEpoch;
    }
    if (value is DateTime) {
      return value.millisecondsSinceEpoch;
    }
    if (value is int) {
      return value;
    }
    return null;
  }

  String _formatLatency(int? valueMs) {
    if (valueMs == null || valueMs < 0) {
      return '-';
    }
    return '${valueMs}ms';
  }

  String _renderScoreTrend(List<int> scores) {
    if (scores.isEmpty) {
      return '-';
    }
    const bars = <String>['▁', '▂', '▃', '▄', '▅', '▆', '▇', '█'];
    return scores.map((score) {
      final normalized = score.clamp(0, 100);
      final index = ((normalized / 100) * (bars.length - 1)).round();
      return bars[index];
    }).join();
  }

  Future<void> _copySnapshot({
    required AppTelemetryState telemetry,
    required bool onlineMismatch,
    required bool camMismatch,
    required bool micMismatch,
    required bool roomMismatch,
    required bool stalePresence,
    required bool firestoreOnline,
    required bool firestoreCamOn,
    required bool firestoreMicOn,
    required String firestoreInRoom,
    required bool uiOnline,
    required bool uiCamOn,
    required bool uiMicOn,
    required String uiInRoom,
  }) async {
    final payload = <String, Object?>{
      'timestamp': DateTime.now().toIso8601String(),
      'userId': _watchedUserId ?? telemetry.authUserId,
      'rtdb': <String, Object?>{
        'session_count': _rtdbSessionCount,
        'online': _rtdbAnyOnline,
        'cam_on': _rtdbAnyCamOn,
        'mic_on': _rtdbAnyMicOn,
        'in_room': _rtdbAnyInRoom,
        'last_seen_ms': _latestRtdbLastSeenMs,
      },
      'firestore': <String, Object?>{
        'online': firestoreOnline,
        'camOn': firestoreCamOn,
        'micOn': firestoreMicOn,
        'inRoom': firestoreInRoom,
      },
      'ui': <String, Object?>{
        'online': uiOnline,
        'cam': uiCamOn,
        'mic': uiMicOn,
        'inRoom': uiInRoom,
      },
      'mismatch': <String, Object?>{
        'online': onlineMismatch,
        'cam': camMismatch,
        'mic': micMismatch,
        'room': roomMismatch,
        'stale_presence': stalePresence,
      },
      'latency': <String, Object?>{
        'rtdb_to_firestore_ms': _rtdbToFirestoreDelayMs,
        'firestore_to_ui_ms': _firestoreToUiDelayMs,
      },
    };

    await Clipboard.setData(
      ClipboardData(text: const JsonEncoder.withIndent('  ').convert(payload)),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Presence snapshot copied to clipboard.')),
    );
  }

  Future<void> _copyEventTimeline() async {
    await Clipboard.setData(
      ClipboardData(text: AppEventInspector.instance.exportJson()),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event timeline copied to clipboard.')),
    );
  }

  void _replayLatestEvent() {
    final latest = AppEventInspector.instance.latest;
    if (latest == null) {
      return;
    }
    AppEventBus.instance.emit(latest.createReplayEvent(), isReplay: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Replayed ${latest.eventType}.')));
  }

  void _registerSecretTap() {
    _secretTapCount += 1;
    _secretTapTimer?.cancel();
    _secretTapTimer = Timer(const Duration(seconds: 2), () {
      _secretTapCount = 0;
    });
    if (_secretTapCount >= 5) {
      _secretTapCount = 0;
      _toggleOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          right: 12,
          bottom: 12,
          child: GestureDetector(
            onLongPress: _toggleOverlay,
            onTap: _registerSecretTap,
            behavior: HitTestBehavior.opaque,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: _isVisible
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.88)
                    : const Color(0xFFD4AF37).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: const Color(0xFFF7EDE2).withValues(alpha: 0.35),
                ),
              ),
              child: const Icon(
                Icons.bug_report_outlined,
                size: 12,
                color: Color(0xFFF7EDE2),
              ),
            ),
          ),
        ),
        if (_isVisible)
          Positioned(
            top: topInset + 12,
            right: 12,
            child: SafeArea(
              child: Material(
                elevation: 14,
                color: const Color(0xF00B0B0B),
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  width: 360,
                  constraints: const BoxConstraints(maxHeight: 560),
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.55),
                    ),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xF01A1114), Color(0xF00B0B0B)],
                    ),
                  ),
                  child: ValueListenableBuilder<AppTelemetryState>(
                    valueListenable: AppTelemetry.notifier,
                    builder: (context, state, _) {
                      final duplicateListeners = state.duplicateListenerKeys;
                      final firestore =
                          _firestorePresence ?? const <String, dynamic>{};
                      final roomHealth = state.roomHealth;
                      final firestoreOnline = _asBool(firestore['isOnline']) ||
                          _asBool(firestore['online']);
                      final firestoreCamOn = _asBool(firestore['camOn']);
                      final firestoreMicOn = _asBool(firestore['micOn']);
                      final firestoreInRoom = _asTrimmedString(
                        firestore['inRoom'] ?? firestore['roomId'],
                      );

                      final uiOnline = state.globalPresenceOnline ??
                          (state.presenceStatus != null &&
                              state.presenceStatus!.toLowerCase() != 'offline');
                      final uiCamOn = state.videoEnabled;
                      final uiMicOn = !state.micMuted;
                      final uiInRoom = (state.inRoom ?? '').trim();

                      final onlineMismatch =
                          (_rtdbAnyOnline != firestoreOnline) ||
                              (firestoreOnline != uiOnline);
                      final camMismatch = (_rtdbAnyCamOn != firestoreCamOn) ||
                          (firestoreCamOn != uiCamOn);
                      final micMismatch = (_rtdbAnyMicOn != firestoreMicOn) ||
                          (firestoreMicOn != uiMicOn);
                      final roomMismatch =
                          (_rtdbAnyInRoom ?? '') != firestoreInRoom ||
                              firestoreInRoom != uiInRoom;
                      final stalePresence = _latestRtdbLastSeenMs != null &&
                          DateTime.now()
                                  .difference(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      _latestRtdbLastSeenMs!,
                                    ),
                                  )
                                  .inSeconds >
                              60;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Live Debug',
                                  style: TextStyle(
                                    color: Color(0xFFF7EDE2),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: _toggleOverlay,
                                icon: const Icon(Icons.close, size: 18),
                                color: const Color(0xFFF7EDE2),
                                splashRadius: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _DebugLine(
                            label: 'Auth',
                            value: state.authUserId ?? 'anonymous',
                          ),
                          _DebugLine(
                            label: 'Auth load',
                            value: state.authLoading ? 'loading' : 'idle',
                          ),
                          _DebugLine(label: 'Room', value: state.roomId ?? '-'),
                          _DebugLine(
                            label: 'Phase',
                            value: state.roomPhase ?? '-',
                          ),
                          _DebugLine(
                            label: 'Participants',
                            value: state.participantCount.toString(),
                          ),
                          _DebugLine(
                            label: 'Camera',
                            value: state.videoEnabled ? 'on' : 'off',
                          ),
                          _DebugLine(
                            label: 'Mic',
                            value: state.micMuted ? 'muted' : 'live',
                          ),
                          _DebugLine(
                            label: 'Presence',
                            value: state.presenceStatus ??
                                state.roomPresenceStatus ??
                                '-',
                          ),
                          _DebugLine(
                            label: 'In room',
                            value: state.inRoom ?? '-',
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Room Health',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _DebugLine(
                            label: 'Status',
                            value:
                                '${roomHealth.label} (${roomHealth.score}/100)',
                          ),
                          _DebugLine(
                            label: 'Trend',
                            value: _renderScoreTrend(roomHealth.recentScores),
                          ),
                          if (roomHealth.recoveryWindowActive)
                            const _DebugLine(
                              label: 'Recovery window',
                              value: 'suppression active',
                            ),
                          if (roomHealth.warningAlertCount > 0)
                            _DebugLine(
                              label: 'Warnings',
                              value: roomHealth.warningAlertCount.toString(),
                            ),
                          if (roomHealth.criticalAlertCount > 0)
                            _DebugLine(
                              label: 'Criticals',
                              value: roomHealth.criticalAlertCount.toString(),
                            ),
                          if (roomHealth.suppressedAlertCount > 0)
                            _DebugLine(
                              label: 'Suppressed',
                              value: roomHealth.suppressedAlertCount.toString(),
                            ),
                          if (roomHealth.duplicateJoinCount > 0)
                            _DebugLine(
                              label: 'Join bursts',
                              value: roomHealth.duplicateJoinCount.toString(),
                            ),
                          if (roomHealth.reconnectBurstCount > 0)
                            _DebugLine(
                              label: 'Reconnect bursts',
                              value: roomHealth.reconnectBurstCount.toString(),
                            ),
                          if (roomHealth.firestoreErrorBurstCount > 0)
                            _DebugLine(
                              label: 'FS error burst',
                              value: roomHealth.firestoreErrorBurstCount
                                  .toString(),
                            ),
                          for (final alert in roomHealth.alerts)
                            _AlertLine(
                              text: 'Health ${alert.code}: ${alert.message}',
                            ),
                          const SizedBox(height: 8),
                          const Text(
                            'Presence Debug',
                            style: TextStyle(
                              color: Color(0xFFD4AF37),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: OutlinedButton.icon(
                              onPressed: () => _copySnapshot(
                                telemetry: state,
                                onlineMismatch: onlineMismatch,
                                camMismatch: camMismatch,
                                micMismatch: micMismatch,
                                roomMismatch: roomMismatch,
                                stalePresence: stalePresence,
                                firestoreOnline: firestoreOnline,
                                firestoreCamOn: firestoreCamOn,
                                firestoreMicOn: firestoreMicOn,
                                firestoreInRoom: firestoreInRoom,
                                uiOnline: uiOnline,
                                uiCamOn: uiCamOn,
                                uiMicOn: uiMicOn,
                                uiInRoom: uiInRoom,
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFF7EDE2),
                                side: BorderSide(
                                  color: const Color(
                                    0xFFD4AF37,
                                  ).withValues(alpha: 0.65),
                                ),
                              ),
                              icon: const Icon(
                                Icons.copy_all_rounded,
                                size: 14,
                              ),
                              label: const Text('Copy Snapshot'),
                            ),
                          ),
                          _DebugLine(
                            label: 'RTDB sessions',
                            value: _rtdbSessionCount.toString(),
                          ),
                          _DebugLine(
                            label: 'RTDB online',
                            value: _rtdbAnyOnline ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'RTDB cam_on',
                            value: _rtdbAnyCamOn ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'RTDB mic_on',
                            value: _rtdbAnyMicOn ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'RTDB in_room',
                            value: _rtdbAnyInRoom ?? '-',
                          ),
                          _DebugLine(
                            label: 'RTDB last_seen',
                            value: _formatLastSeenAge(),
                          ),
                          _DebugLine(
                            label: 'RTDB -> Firestore',
                            value: _formatLatency(_rtdbToFirestoreDelayMs),
                          ),
                          _DebugLine(
                            label: 'Firestore -> UI',
                            value: _formatLatency(_firestoreToUiDelayMs),
                          ),
                          const SizedBox(height: 4),
                          _DebugLine(
                            label: 'Firestore online',
                            value: firestoreOnline ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'Firestore camOn',
                            value: firestoreCamOn ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'Firestore micOn',
                            value: firestoreMicOn ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'Firestore inRoom',
                            value:
                                firestoreInRoom.isEmpty ? '-' : firestoreInRoom,
                          ),
                          const SizedBox(height: 4),
                          _DebugLine(
                            label: 'UI online',
                            value: uiOnline ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'UI cam',
                            value: uiCamOn ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'UI mic',
                            value: uiMicOn ? 'true' : 'false',
                          ),
                          _DebugLine(
                            label: 'UI inRoom',
                            value: uiInRoom.isEmpty ? '-' : uiInRoom,
                          ),
                          _DebugLine(
                            label: 'Listeners',
                            value: state.activeListenerCount.toString(),
                          ),
                          _DebugLine(
                            label: 'Reads/Writes/Snaps',
                            value:
                                '${state.firestoreReadCount}/${state.firestoreWriteCount}/${state.firestoreSnapshotCount}',
                          ),
                          if (state.cameraStatus != null &&
                              state.cameraStatus!.isNotEmpty)
                            _DebugLine(
                              label: 'Camera status',
                              value: state.cameraStatus!,
                            ),
                          if (state.callError != null &&
                              state.callError!.isNotEmpty)
                            _DebugLine(
                              label: 'Call error',
                              value: state.callError!,
                            ),
                          if (state.authError != null &&
                              state.authError!.isNotEmpty)
                            _DebugLine(
                              label: 'Auth error',
                              value: state.authError!,
                            ),
                          if (state.roomError != null &&
                              state.roomError!.isNotEmpty)
                            _DebugLine(
                              label: 'Room error',
                              value: state.roomError!,
                            ),
                          if (state.cameraMismatch)
                            const _AlertLine(
                              text: 'Camera mismatch: UI on, Firestore off',
                            ),
                          if (state.presenceMismatch)
                            const _AlertLine(
                              text: 'Presence mismatch: offline or wrong room',
                            ),
                          if (onlineMismatch)
                            const _AlertLine(
                              text:
                                  'ONLINE mismatch: RTDB / Firestore / UI disagree',
                            ),
                          if (camMismatch)
                            const _AlertLine(
                              text:
                                  'CAM mismatch: RTDB / Firestore / UI disagree',
                            ),
                          if (micMismatch)
                            const _AlertLine(
                              text:
                                  'MIC mismatch: RTDB / Firestore / UI disagree',
                            ),
                          if (roomMismatch)
                            const _AlertLine(
                              text:
                                  'ROOM mismatch: RTDB / Firestore / UI disagree',
                            ),
                          if (stalePresence)
                            const _AlertLine(
                              text:
                                  'STALE PRESENCE: last_seen is older than 60s',
                            ),
                          if (state.staleParticipantIds.isNotEmpty)
                            _AlertLine(
                              text:
                                  'Stale users: ${state.staleParticipantIds.join(', ')}',
                            ),
                          if (duplicateListeners.isNotEmpty)
                            _AlertLine(
                              text:
                                  'Duplicate listeners: ${duplicateListeners.join(', ')}',
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Text(
                                'System Timeline',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Spacer(),
                              ToggleButtons(
                                isSelected: [
                                  _selectedTimelineIndex == 0,
                                  _selectedTimelineIndex == 1,
                                ],
                                onPressed: (index) {
                                  setState(
                                    () => _selectedTimelineIndex = index,
                                  );
                                },
                                constraints: const BoxConstraints(
                                  minHeight: 28,
                                  minWidth: 64,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                selectedColor: const Color(0xFF0B0B0B),
                                fillColor: const Color(0xFFD4AF37),
                                color: const Color(0xFFF7EDE2),
                                children: const [Text('App'), Text('Bus')],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Flexible(
                            child: _selectedTimelineIndex == 0
                                ? ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: state.recentEvents.length,
                                    itemBuilder: (context, index) {
                                      final event = state.recentEvents[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Text(
                                          '${event.timestamp.toIso8601String().substring(11, 19)} '
                                          '[${event.level.toUpperCase()}] '
                                          '${event.domain}/${event.action} '
                                          '${event.result ?? ''} '
                                          '${event.message}',
                                          style: const TextStyle(
                                            color: Color(0xFFF7EDE2),
                                            fontSize: 11,
                                            height: 1.3,
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : AnimatedBuilder(
                                    animation: AppEventInspector.instance,
                                    builder: (context, _) {
                                      final entries =
                                          AppEventInspector.instance.entries;
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                '${entries.length} captured',
                                                style: const TextStyle(
                                                  color: Color(0xFFF7EDE2),
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              FilterChip(
                                                selected:
                                                    _groupBusTimelineBySession,
                                                onSelected: (value) {
                                                  setState(() {
                                                    _groupBusTimelineBySession =
                                                        value;
                                                  });
                                                },
                                                label: const Text(
                                                  'Group by session',
                                                ),
                                                labelStyle: const TextStyle(
                                                  fontSize: 10,
                                                ),
                                                selectedColor: const Color(
                                                  0xFFD4AF37,
                                                ),
                                                backgroundColor:
                                                    Colors.transparent,
                                                checkmarkColor: const Color(
                                                  0xFF0B0B0B,
                                                ),
                                                side: BorderSide(
                                                  color: const Color(
                                                    0xFFD4AF37,
                                                  ).withValues(alpha: 0.5),
                                                ),
                                              ),
                                              const Spacer(),
                                              IconButton(
                                                onPressed: entries.isEmpty
                                                    ? null
                                                    : _copyEventTimeline,
                                                icon: const Icon(
                                                  Icons.copy_all_rounded,
                                                  size: 16,
                                                ),
                                                color: const Color(0xFFF7EDE2),
                                                splashRadius: 16,
                                              ),
                                              IconButton(
                                                onPressed: entries.isEmpty
                                                    ? null
                                                    : _replayLatestEvent,
                                                icon: const Icon(
                                                  Icons.replay_rounded,
                                                  size: 16,
                                                ),
                                                color: const Color(0xFFF7EDE2),
                                                splashRadius: 16,
                                              ),
                                              IconButton(
                                                onPressed: entries.isEmpty
                                                    ? null
                                                    : AppEventInspector
                                                        .instance.clear,
                                                icon: const Icon(
                                                  Icons.delete_sweep_outlined,
                                                  size: 16,
                                                ),
                                                color: const Color(0xFFF7EDE2),
                                                splashRadius: 16,
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Expanded(
                                            child: entries.isEmpty
                                                ? const Center(
                                                    child: Text(
                                                      'No bus events captured yet.',
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFFF7EDE2,
                                                        ),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  )
                                                : ListView.builder(
                                                    itemCount: entries.length,
                                                    itemBuilder:
                                                        (context, index) {
                                                      final entry =
                                                          entries[index];
                                                      final previous = index > 0
                                                          ? entries[index - 1]
                                                          : null;
                                                      final showGroupHeader =
                                                          _groupBusTimelineBySession &&
                                                              (previous ==
                                                                      null ||
                                                                  previous.sessionId !=
                                                                      entry
                                                                          .sessionId);
                                                      return Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .only(
                                                          bottom: 8,
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            if (showGroupHeader)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets
                                                                        .only(
                                                                  bottom: 6,
                                                                ),
                                                                child:
                                                                    _EventGroupHeader(
                                                                  entry: entry,
                                                                ),
                                                              ),
                                                            _EventInspectorTile(
                                                              entry: entry,
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    },
                                                  ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DebugLine extends StatelessWidget {
  const _DebugLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(color: Color(0xFFF7EDE2), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventGroupHeader extends StatelessWidget {
  const _EventGroupHeader({required this.entry});

  final EventInspectorEntry entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'Session ${entry.sessionId}  •  Flow ${entry.correlationId}',
        style: const TextStyle(
          color: Color(0xFFD4AF37),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventInspectorTile extends StatelessWidget {
  const _EventInspectorTile({required this.entry});

  final EventInspectorEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.dropped
        ? const Color(0xFF9B2535)
        : entry.isReplay
            ? const Color(0xFFD4AF37)
            : const Color(0xFF3FB27F);
    final payloadSummary = entry.payload.entries
        .where(
          (item) =>
              item.value != null && item.value.toString().trim().isNotEmpty,
        )
        .take(3)
        .map((item) => '${item.key}=${item.value}')
        .join(' • ');
    final traceSummary = entry.consumerTraces
        .map((trace) => '${trace.consumer}:${trace.status}')
        .join(' • ');
    final tagSummary = entry.tags.join(' • ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '#${entry.sequence} ${entry.eventType}',
            style: const TextStyle(
              color: Color(0xFFF7EDE2),
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            payloadSummary.isEmpty ? entry.eventId : payloadSummary,
            style: const TextStyle(
              color: Color(0xFFF7EDE2),
              fontSize: 10,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'session=${entry.sessionId}',
            style: TextStyle(
              color: accent.withValues(alpha: 0.95),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'flow=${entry.correlationId}',
            style: const TextStyle(color: Color(0xFFF7EDE2), fontSize: 10),
          ),
          if (tagSummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              tagSummary,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (traceSummary.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              traceSummary,
              style: TextStyle(
                color: accent,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if ((entry.note ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(entry.note!, style: TextStyle(color: accent, fontSize: 10)),
          ],
        ],
      ),
    );
  }
}

class _AlertLine extends StatelessWidget {
  const _AlertLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF781E2B).withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF9B2535).withValues(alpha: 0.7),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFFF7EDE2),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
