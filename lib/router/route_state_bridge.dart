import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../core/telemetry/app_telemetry.dart';

class RouteStateBridge {
  final Ref ref;
  final GoRouter router;
  int _routeGeneration = 0;

  RouteStateBridge(this.ref, this.router) {
    // This is the "Safety Gate"
    // We wait for the first frame to complete before attaching the listener
    // to avoid triggering updates during the initial build/layout cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.routerDelegate.addListener(_listener);
      // Also trigger initial update
      _handleRouteUpdate();
    });
  }

  void _listener() {
    _handleRouteUpdate();
  }

  void _handleRouteUpdate() {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) return;

    final location = configuration.uri.path;
    final previousLocation =
        ref.read(streamLifecycleManagerProvider).currentRoutePath;
    ref.read(streamLifecycleManagerProvider).updateRoute(location);
    if (location == previousLocation) {
      return;
    }

    final generation = ++_routeGeneration;
    final committedAt = DateTime.now();
    AppTelemetry.logAction(
      domain: 'navigation',
      action: 'route_committed',
      message: 'Route navigation committed.',
      result: 'success',
      metadata: <String, Object?>{
        'from': previousLocation,
        'to': location,
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (generation != _routeGeneration) {
        return;
      }
      AppTelemetry.logAction(
        domain: 'navigation',
        action: 'route_first_frame',
        message: 'Route rendered its first frame.',
        result: 'success',
        metadata: <String, Object?>{
          'route': location,
          'duration_ms': DateTime.now().difference(committedAt).inMilliseconds,
        },
      );
    });
  }

  void dispose() {
    router.routerDelegate.removeListener(_listener);
  }
}

// Provider to manage the bridge lifecycle
final routeStateBridgeProvider =
    Provider.family<RouteStateBridge, GoRouter>((ref, router) {
  final bridge = RouteStateBridge(ref, router);
  ref.onDispose(() => bridge.dispose());
  return bridge;
});
