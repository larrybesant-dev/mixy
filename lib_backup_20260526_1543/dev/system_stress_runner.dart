import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/controllers/auth_controller.dart';
import '../observability/system_event_bus.dart';
import '../observability/system_trace_analyzer.dart';

const String _stressRunnerEnabledDefine = String.fromEnvironment(
  'MIXVY_STRESS_RUNNER',
  defaultValue: 'false',
);

const String _stressAuthFlipEnabledDefine = String.fromEnvironment(
  'MIXVY_STRESS_AUTH_FLIP',
  defaultValue: 'false',
);

const bool kEnableSystemStressRunner =
    kDebugMode && _stressRunnerEnabledDefine == 'true';

const bool kEnableStressAuthFlipCycle =
    kDebugMode && _stressAuthFlipEnabledDefine == 'true';

class MixVySystemStressRunner {
  MixVySystemStressRunner._();

  static bool _isRunning = false;

  static Future<Map<String, dynamic>?> run({
    required WidgetRef ref,
    required GoRouter router,
    required AuthState authState,
  }) async {
    if (!kEnableSystemStressRunner || _isRunning) {
      return null;
    }

    _isRunning = true;
    final bus = SystemEventBus.instance;
    final observedEvents = <SystemEvent>[...bus.snapshot()];
    final eventSubscription = bus.stream.listen(observedEvents.add);
    final analyzer = const SystemTraceAnalyzer();

    try {
      bus.emitNow(
        'STRESS_RUN_START',
        meta: <String, dynamic>{
          'signedInStable': authState.isAuthenticatedStable,
        },
      );

      final deepLinks = <String>[
        '/chat/thread-123',
        '/profile/test-missing-user-404',
        '/settings',
      ];

      for (final route in deepLinks) {
        await _probeRoute(router: router, route: route);
      }

      final burstRoutes = <String>[
        '/home',
        '/messages',
        '/rooms',
        '/speed-dating',
        '/settings',
      ];
      bus.emitNow(
        'STRESS_NAV_BURST_START',
        meta: <String, dynamic>{'hops': 20},
      );
      for (var i = 0; i < 20; i += 1) {
        final target = burstRoutes[i % burstRoutes.length];
        bus.emitNow(
          'STRESS_NAV_BURST_HOP',
          meta: <String, dynamic>{'index': i, 'route': target},
        );
        router.go(target);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      await Future<void>.delayed(const Duration(milliseconds: 400));

      bus.emitNow(
        'STRESS_RUN_COMPLETE',
        meta: <String, dynamic>{'authFlipEnabled': kEnableStressAuthFlipCycle},
      );

      await Future<void>.delayed(const Duration(milliseconds: 120));
      final summary = analyzer.analyze(observedEvents);
      final report = summary.toJson();
      debugPrint('MIXVY_STRESS_REPORT ${jsonEncode(report)}');
      return report;
    } finally {
      await eventSubscription.cancel();
      _isRunning = false;
    }
  }

  static Future<void> _probeRoute({
    required GoRouter router,
    required String route,
  }) async {
    final bus = SystemEventBus.instance;
    final stopwatch = Stopwatch()..start();
    bus.emitNow(
      'STRESS_ROUTE_START',
      meta: <String, dynamic>{'requestedRoute': route},
    );

    router.go(route);

    String current = _currentRoute(router);
    var stableTicks = 0;
    for (var i = 0; i < 40; i += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 60));
      final next = _currentRoute(router);
      if (next == current) {
        stableTicks += 1;
      } else {
        current = next;
        stableTicks = 0;
      }
      if (stableTicks >= 4) {
        break;
      }
    }

    stopwatch.stop();
    bus.emitNow(
      'STRESS_ROUTE_FINAL',
      meta: <String, dynamic>{
        'requestedRoute': route,
        'finalRoute': _currentRoute(router),
        'durationMs': stopwatch.elapsedMilliseconds,
      },
    );
  }

  static String _currentRoute(GoRouter router) {
    final uri = router.routeInformationProvider.value.uri;
    final path = uri.path.isEmpty ? '/' : uri.path;
    if (uri.query.isEmpty) {
      return path;
    }
    return '$path?${uri.query}';
  }
}
