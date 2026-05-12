import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/streams/stream_lifecycle_manager.dart';

class RouteStateBridge {
  final Ref ref;
  final GoRouter router;

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

    final location = configuration.last.matchedLocation;
    
    // Pushes the route change into StreamLifecycleManager
    ref.read(streamLifecycleManagerProvider).updateRoute(location);
  }

  void dispose() {
    router.routerDelegate.removeListener(_listener);
  }
}

// Provider to manage the bridge lifecycle
final routeStateBridgeProvider = Provider.family<RouteStateBridge, GoRouter>((ref, router) {
  final bridge = RouteStateBridge(ref, router);
  ref.onDispose(() => bridge.dispose());
  return bridge;
});