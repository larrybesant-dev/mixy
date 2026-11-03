import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'app_telemetry.dart';

extension type _LayoutShiftEntry(JSObject _) implements web.PerformanceEntry {
  external double get value;
  external bool get hadRecentInput;
}

class _WebVitalsMonitor {
  final List<web.PerformanceObserver> _observers = [];
  double? _firstContentfulPaint;
  double? _largestContentfulPaint;
  double _cumulativeLayoutShift = 0;
  double _interactionToNextPaint = 0;
  double? _navigationDuration;
  int _longTaskCount = 0;
  double _longestTask = 0;
  bool _flushed = false;

  void start() {
    _observe('paint', _recordPaint);
    _observe('largest-contentful-paint', _recordLargestContentfulPaint);
    _observe('layout-shift', _recordLayoutShift);
    _observe('event', _recordEventTiming, durationThreshold: 40);
    _observe('navigation', _recordNavigation);
    _observe('longtask', _recordLongTask);

    web.document.addEventListener(
      'visibilitychange',
      ((web.Event _) {
        if (web.document.visibilityState == 'hidden') {
          _flush();
        }
      }).toJS,
    );
    Timer(const Duration(seconds: 15), _flush);
  }

  void _observe(
    String type,
    void Function(web.PerformanceEntry entry) onEntry, {
    double? durationThreshold,
  }) {
    try {
      final supported = web.PerformanceObserver.supportedEntryTypes.toDart
          .map((entry) => entry.toDart)
          .contains(type);
      if (!supported) return;

      final observer = web.PerformanceObserver(
        ((web.PerformanceObserverEntryList list,
            web.PerformanceObserver observer) {
          for (final entry in list.getEntries().toDart) {
            onEntry(entry);
          }
        }).toJS,
      );
      observer.observe(
        web.PerformanceObserverInit(
          type: type,
          buffered: true,
          durationThreshold: durationThreshold ?? 0,
        ),
      );
      _observers.add(observer);
    } catch (error, stackTrace) {
      AppTelemetry.logAction(
        level: 'warn',
        domain: 'performance',
        action: 'web_vitals_observer_failed',
        message: 'A browser performance observer could not start.',
        result: 'unsupported',
        metadata: <String, Object?>{'entry_type': type},
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _recordPaint(web.PerformanceEntry entry) {
    if (entry.name == 'first-contentful-paint') {
      _firstContentfulPaint = entry.startTime;
    }
  }

  void _recordLargestContentfulPaint(web.PerformanceEntry entry) {
    _largestContentfulPaint = entry.startTime;
  }

  void _recordLayoutShift(web.PerformanceEntry entry) {
    final shift = _LayoutShiftEntry(entry as JSObject);
    if (!shift.hadRecentInput) {
      _cumulativeLayoutShift += shift.value;
    }
  }

  void _recordEventTiming(web.PerformanceEntry entry) {
    if (entry.duration > _interactionToNextPaint) {
      _interactionToNextPaint = entry.duration;
    }
  }

  void _recordNavigation(web.PerformanceEntry entry) {
    _navigationDuration = entry.duration;
  }

  void _recordLongTask(web.PerformanceEntry entry) {
    _longTaskCount++;
    if (entry.duration > _longestTask) {
      _longestTask = entry.duration;
    }
  }

  void _flush() {
    if (_flushed) return;
    _flushed = true;
    for (final observer in _observers) {
      observer.disconnect();
    }

    AppTelemetry.logAction(
      domain: 'performance',
      action: 'web_vitals',
      message: 'Browser performance metrics captured.',
      result: 'success',
      metadata: <String, Object?>{
        if (_firstContentfulPaint != null)
          'fcp_ms': _firstContentfulPaint!.round(),
        if (_largestContentfulPaint != null)
          'lcp_ms': _largestContentfulPaint!.round(),
        'cls_milli': (_cumulativeLayoutShift * 1000).round(),
        if (_interactionToNextPaint > 0)
          'inp_ms': _interactionToNextPaint.round(),
        if (_navigationDuration != null)
          'navigation_ms': _navigationDuration!.round(),
        'long_task_count': _longTaskCount,
        'longest_task_ms': _longestTask.round(),
      },
    );
  }
}

_WebVitalsMonitor? _monitor;

void startWebVitalsMonitoring() {
  (_monitor ??= _WebVitalsMonitor()).start();
}
