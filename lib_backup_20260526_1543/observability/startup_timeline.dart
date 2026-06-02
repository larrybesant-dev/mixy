import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'startup_timeline_runtime_sink.dart';
import 'system_event_bus.dart';

// ---------------------------------------------------------------------------
// Internal helpers — Timeline events work in debug AND profile mode and are
// visible in the DevTools Performance tab. They are no-ops in release builds
// when the observatory is absent, so there is zero overhead at launch.
// ---------------------------------------------------------------------------

const bool kStartupDebug = true;

enum StartupCheckpoint {
  mainStart,
  bindingReady,
  firebaseReady,
  bootstrapResolved,
  firstFrameRendered,
  firstInteractiveReady,

  /// Fired when the first WebRTC channel successfully connects.
  rtcConnected,

  /// Fired on the first deliberate user gesture after the app is interactive.
  /// This closes the loop between "system ready" and "user felt ready".
  firstUserAction,
}

enum BootstrapResolution { ready, degraded, failed }

/// Canonical startup profiler for comparable cold-start diagnostics.
///
/// Logs are delta-only from `startTime` and only for approved checkpoints.
class StartupProfiler {
  StartupProfiler._()
      : startTime = DateTime.now(),
        _elapsed = Stopwatch()..start() {
    // Open the root timeline block immediately when the profiler is created.
    // This is visible in the DevTools Performance → Timeline view.
    developer.Timeline.startSync(
      'MixVy:AppBoot',
      arguments: <String, dynamic>{'launch_type': 'cold'},
    );
  }

  static final StartupProfiler instance = StartupProfiler._();

  final DateTime startTime;
  final Stopwatch _elapsed;
  final Set<StartupCheckpoint> _marks = <StartupCheckpoint>{};
  DateTime? _firstFrameTime;
  DateTime? _firstInteractiveTime;
  DateTime? _warmStartTime;

  void markMainStart() {
    _mark(StartupCheckpoint.mainStart);
  }

  void markBindingReady() {
    _mark(StartupCheckpoint.bindingReady);
  }

  void markFirebaseReady({
    required bool success,
    Object? error,
    StackTrace? stackTrace,
  }) {
    _mark(
      StartupCheckpoint.firebaseReady,
      detail: 'status=${success ? 'ok' : 'failed'}',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void markBootstrapResolved({
    required BootstrapResolution resolution,
    String? detail,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final suffix = detail == null || detail.isEmpty ? '' : ' $detail';
    _mark(
      StartupCheckpoint.bootstrapResolved,
      detail: 'status=${resolution.name}$suffix',
      error: error,
      stackTrace: stackTrace,
    );
  }

  void markFirstFrameRendered() {
    if (_marks.contains(StartupCheckpoint.firstFrameRendered)) {
      return;
    }
    _firstFrameTime ??= DateTime.now();
    _emitComputedTiming(
      label: 'first_frame_rendered_time',
      duration: _firstFrameTime!.difference(startTime),
      launchType: 'cold',
    );
    _mark(StartupCheckpoint.firstFrameRendered);
    // Close the root boot block now that the first frame is painted.
    developer.Timeline.finishSync();
  }

  void markFirstInteractiveReady({String launchType = 'cold'}) {
    if (_marks.contains(StartupCheckpoint.firstInteractiveReady)) {
      return;
    }
    _firstInteractiveTime ??= DateTime.now();
    _emitComputedTiming(
      label: 'first_interactive_ready_time',
      duration: _firstInteractiveTime!.difference(startTime),
      launchType: launchType,
    );
    _mark(
      StartupCheckpoint.firstInteractiveReady,
      detail: 'launch_type=$launchType',
    );
    // Keep funnel tracker in sync — first interactive = first screen visible.
    SessionFunnelTracker.instance.markFirstScreenVisible();
  }

  void markRtcConnected() {
    _mark(StartupCheckpoint.rtcConnected);
  }

  void markWarmStartBegin() {
    _warmStartTime = DateTime.now();
    developer.Timeline.startSync(
      'MixVy:WarmBoot',
      arguments: <String, dynamic>{'launch_type': 'warm'},
    );
    _emitComputedTiming(
      label: 'warm_start_begin_time',
      duration: Duration.zero,
      launchType: 'warm',
    );
  }

  void markWarmInteractiveReady() {
    final warmStartTime = _warmStartTime;
    if (warmStartTime == null) {
      return;
    }
    developer.Timeline.finishSync();
    _emitComputedTiming(
      label: 'warm_start_duration',
      duration: DateTime.now().difference(warmStartTime),
      launchType: 'warm',
    );
  }

  void markAppStartTime() {
    _emitComputedTiming(
      label: 'app_start_time',
      duration: Duration.zero,
      launchType: 'cold',
    );
  }

  /// Call this on the first deliberate user gesture inside the app
  /// (tap, scroll, navigation). Only the first call is recorded; subsequent
  /// calls are no-ops. [context] is a free-form label shown in DevTools
  /// (e.g. 'social_pulse_tap', 'room_card_tap', 'dashboard_scroll').
  void markFirstUserAction({String context = 'unknown'}) {
    if (_marks.contains(StartupCheckpoint.firstUserAction)) {
      return;
    }
    developer.Timeline.instantSync(
      'MixVy:FirstUserAction',
      arguments: <String, dynamic>{
        'context': context,
        'elapsed_ms': _elapsed.elapsedMilliseconds,
      },
    );
    _emitComputedTiming(
      label: 'first_user_action_time',
      duration: Duration(milliseconds: _elapsed.elapsedMilliseconds),
      launchType: 'cold',
    );
    _mark(StartupCheckpoint.firstUserAction, detail: 'context=$context');
    // Keep funnel tracker in sync — first user action = first tap.
    SessionFunnelTracker.instance.markFirstTap(context: context);
  }

  void _emitComputedTiming({
    required String label,
    required Duration duration,
    required String launchType,
  }) {
    final valueMs = duration.inMilliseconds;

    // Persist in the in-process metric store (works in ALL build modes).
    StartupMetrics._record(label, valueMs);

    if (!kStartupDebug) {
      return;
    }
    final message =
        'startup_metric name=$label launch_type=$launchType value_ms=$valueMs';
    if (kIsWeb) {
      emitStartupMessageToRuntime(message);
    }
    developer.log(message, name: 'startup_timing');

    // dart:developer flow event — visible in DevTools CPU/Timeline tab in
    // debug AND profile mode regardless of stdout suppression.
    developer.Timeline.instantSync(
      'startup_metric',
      arguments: <String, dynamic>{
        'name': label,
        'launch_type': launchType,
        'value_ms': valueMs,
      },
    );
  }

  void _mark(
    StartupCheckpoint checkpoint, {
    String? detail,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_marks.contains(checkpoint)) return;
    _marks.add(checkpoint);

    final elapsedMs = _elapsed.elapsedMilliseconds;

    // Persist every checkpoint regardless of build mode.
    StartupMetrics._record('checkpoint.${checkpoint.name}', elapsedMs);

    if (!kStartupDebug) return;

    final suffix = (detail == null || detail.isEmpty) ? '' : ' $detail';
    final message = '+${elapsedMs}ms startup.${checkpoint.name}$suffix';

    if (kIsWeb) {
      emitStartupMessageToRuntime(message);
    }

    SystemEventBus.instance.emit(
      SystemEvent(
        type: 'STARTUP_CHECKPOINT',
        timestamp: DateTime.now(),
        meta: <String, dynamic>{
          'checkpoint': checkpoint.name,
          'detail': detail,
          'hasError': error != null,
        },
      ),
    );

    developer.log(
      message,
      name: 'startup_timing',
      error: error,
      stackTrace: stackTrace,
    );

    developer.Timeline.instantSync(
      'startup.${checkpoint.name}',
      arguments: <String, dynamic>{
        'elapsed_ms': elapsedMs,
        'detail': detail ?? '',
      },
    );
  }
}

// ---------------------------------------------------------------------------
// StartupMetrics — persistent, release-safe timing store
//
// Written to on every checkpoint and metric emission.
// Safe to read from any provider, overlay, or analytics export.
// Works in debug, profile, and release without any dependencies.
// ---------------------------------------------------------------------------
class StartupMetrics {
  StartupMetrics._();

  static final Map<String, int> _data = <String, int>{};

  static void _record(String key, int valueMs) {
    _data[key] = valueMs;
  }

  /// Snapshot of all recorded timing marks (ms since app start).
  static Map<String, int> dump() => Map<String, int>.unmodifiable(_data);

  /// Convenience getters for the four canonical targets.
  static int? get appStartMs => _data['app_start_time'];
  static int? get firstFrameMs => _data['first_frame_rendered_time'];
  static int? get firstInteractiveMs => _data['first_interactive_ready_time'];
  static int? get firstUserActionMs => _data['first_user_action_time'];
  static int? get warmStartDurationMs => _data['warm_start_duration'];

  /// Gap between system-interactive and first user action.
  /// A large value here indicates the app felt slow even after it was ready.
  static int? get perceivedLatencyMs {
    final interactive = firstInteractiveMs;
    final action = firstUserActionMs;
    if (interactive == null || action == null) return null;
    return action - interactive;
  }

  /// Whether cold-start performance meets the 3 s usable-UI target.
  static bool get coldStartOnTarget {
    final ms = firstInteractiveMs;
    return ms != null && ms <= 3000;
  }

  /// Whether warm-start performance meets the 1.5 s target.
  static bool get warmStartOnTarget {
    final ms = warmStartDurationMs;
    return ms != null && ms <= 1500;
  }
}

// ---------------------------------------------------------------------------
// SessionFunnelTracker — first-60-second beta instrumentation
//
// Tracks the key conversion moments in a new user's first session.
// All writes are in-process, release-safe, and zero-dependency.
// Read via SessionFunnelTracker.snapshot for export to analytics.
// ---------------------------------------------------------------------------

/// Immutable snapshot of a completed or in-progress funnel.
class SessionFunnelSnapshot {
  const SessionFunnelSnapshot({
    required this.appOpenMs,
    this.firstScreenVisibleMs,
    this.firstTapMs,
    this.firstSuccessActionMs,
    this.sessionDropoffMs,
    this.pulseImpressions,
    this.pulseTaps,
  });

  /// Epoch ms when the app opened (matches StartupProfiler.startTime).
  final int appOpenMs;

  /// Ms elapsed when the first interactive screen was visible.
  final int? firstScreenVisibleMs;

  /// Ms elapsed when the user first tapped anything.
  final int? firstTapMs;

  /// Ms elapsed when the user completed a meaningful action (joined room,
  /// sent message, followed user, tapped "Find People", etc.).
  final int? firstSuccessActionMs;

  /// Ms elapsed when the session ended (app backgrounded or closed).
  final int? sessionDropoffMs;

  /// How many Social Pulse items were rendered (impressions).
  final int? pulseImpressions;

  /// How many Social Pulse items were tapped.
  final int? pulseTaps;

  /// Conversion rate: pulseTaps / pulseImpressions. Null if no impressions.
  double? get pulseConversionRate {
    final imp = pulseImpressions;
    final taps = pulseTaps;
    if (imp == null || imp == 0 || taps == null) return null;
    return taps / imp;
  }

  /// Gap from first interactive to first success action.
  int? get timeToSuccessMs {
    final visible = firstScreenVisibleMs;
    final success = firstSuccessActionMs;
    if (visible == null || success == null) return null;
    return success - visible;
  }

  Map<String, dynamic> toMap() => <String, dynamic>{
        'app_open_ms': appOpenMs,
        if (firstScreenVisibleMs != null)
          'first_screen_visible_ms': firstScreenVisibleMs,
        if (firstTapMs != null) 'first_tap_ms': firstTapMs,
        if (firstSuccessActionMs != null)
          'first_success_action_ms': firstSuccessActionMs,
        if (sessionDropoffMs != null) 'session_dropoff_ms': sessionDropoffMs,
        if (pulseImpressions != null) 'pulse_impressions': pulseImpressions,
        if (pulseTaps != null) 'pulse_taps': pulseTaps,
        if (pulseConversionRate != null)
          'pulse_conversion_rate': double.parse(
            pulseConversionRate!.toStringAsFixed(3),
          ),
        if (timeToSuccessMs != null) 'time_to_success_ms': timeToSuccessMs,
      };
}

class SessionFunnelTracker {
  SessionFunnelTracker._()
      : _startMs = DateTime.now().millisecondsSinceEpoch,
        _elapsed = Stopwatch()..start();

  static final SessionFunnelTracker instance = SessionFunnelTracker._();

  final int _startMs;
  final Stopwatch _elapsed;

  int? _firstScreenVisibleMs;
  int? _firstTapMs;
  int? _firstSuccessActionMs;
  int? _sessionDropoffMs;
  int _pulseImpressions = 0;
  int _pulseTaps = 0;

  int get _now => _elapsed.elapsedMilliseconds;

  // ── Funnel events ─────────────────────────────────────────────────────────

  /// Call when the first interactive screen frame is visible to the user.
  /// Typically wired from `markFirstInteractiveReady`.
  void markFirstScreenVisible() {
    _firstScreenVisibleMs ??= _now;
    developer.Timeline.instantSync(
      'MixVy:Funnel:FirstScreenVisible',
      arguments: <String, dynamic>{'elapsed_ms': _now},
    );
  }

  /// Call on first deliberate user gesture. Aliased from
  /// `StartupProfiler.markFirstUserAction` so both systems stay in sync.
  void markFirstTap({String context = 'unknown'}) {
    if (_firstTapMs != null) return;
    _firstTapMs = _now;
    developer.Timeline.instantSync(
      'MixVy:Funnel:FirstTap',
      arguments: <String, dynamic>{'elapsed_ms': _now, 'context': context},
    );
  }

  /// Call when the user completes a meaningful action: joined a room,
  /// sent a message, followed someone, or completed first-session entry.
  void markFirstSuccessAction({String action = 'unknown'}) {
    if (_firstSuccessActionMs != null) return;
    _firstSuccessActionMs = _now;
    developer.Timeline.instantSync(
      'MixVy:Funnel:FirstSuccess',
      arguments: <String, dynamic>{'elapsed_ms': _now, 'action': action},
    );
    developer.log(
      'funnel first_success action=$action elapsed_ms=$_now',
      name: 'SessionFunnel',
    );
  }

  /// Call from `didChangeAppLifecycleState` when the app is paused/detached.
  void markSessionDropoff() {
    _sessionDropoffMs ??= _now;
    developer.Timeline.instantSync(
      'MixVy:Funnel:SessionDropoff',
      arguments: <String, dynamic>{'elapsed_ms': _now},
    );
  }

  // ── Social Pulse engagement ───────────────────────────────────────────────

  /// Call once per Social Pulse render with the number of items displayed.
  void recordPulseImpression(int itemCount) {
    _pulseImpressions += itemCount;
  }

  /// Call on each Social Pulse item tap.
  void recordPulseTap() {
    _pulseTaps += 1;
  }

  // ── Read ──────────────────────────────────────────────────────────────────

  SessionFunnelSnapshot get snapshot => SessionFunnelSnapshot(
        appOpenMs: _startMs,
        firstScreenVisibleMs: _firstScreenVisibleMs,
        firstTapMs: _firstTapMs,
        firstSuccessActionMs: _firstSuccessActionMs,
        sessionDropoffMs: _sessionDropoffMs,
        pulseImpressions: _pulseImpressions > 0 ? _pulseImpressions : null,
        pulseTaps: _pulseTaps > 0 ? _pulseTaps : null,
      );
}
