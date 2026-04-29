import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'startup_timeline_runtime_sink.dart';
import 'system_event_bus.dart';

const bool kStartupDebug = true;

enum StartupCheckpoint {
  mainStart,
  bindingReady,
  firebaseReady,
  bootstrapResolved,
  firstFrameRendered,
}

enum BootstrapResolution { ready, degraded, failed }

/// Canonical startup profiler for comparable cold-start diagnostics.
///
/// Logs are delta-only from `startTime` and only for approved checkpoints.
class StartupProfiler {
  StartupProfiler._()
    : startTime = DateTime.now(),
      _elapsed = Stopwatch()..start();

  static final StartupProfiler instance = StartupProfiler._();

  final DateTime startTime;
  final Stopwatch _elapsed;
  final Set<StartupCheckpoint> _marks = <StartupCheckpoint>{};

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
    _mark(StartupCheckpoint.firstFrameRendered);
  }

  void _mark(
    StartupCheckpoint checkpoint, {
    String? detail,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (_marks.contains(checkpoint)) return;
    _marks.add(checkpoint);
    if (!kStartupDebug) return;

    final suffix = (detail == null || detail.isEmpty) ? '' : ' $detail';
    final message =
        '+${_elapsed.elapsedMilliseconds}ms startup.${checkpoint.name}$suffix';

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
  }
}
