import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/streams/stream_lifecycle_manager.dart';
import 'app_router.dart';

class RouteStateBridge {
  RouteStateBridge({
    required this.router,
    required void Function(String route) onRouteChanged,
  }) : _onRouteChanged = onRouteChanged {
    _listener = _handleRouteUpdate;
    router.routerDelegate.addListener(_listener);
    // Schedule initial route update for next frame to ensure router is ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleRouteUpdate());
  }

  final GoRouter router;
  final void Function(String route) _onRouteChanged;
  late final VoidCallback _listener;
  String? _lastRoute;

  void _handleRouteUpdate() {
    final configuration = router.routerDelegate.currentConfiguration;
    if (configuration.isEmpty) {
      return;
    }

    final location = configuration.last.matchedLocation;
    if (location == _lastRoute) {
      return;
    }

    _lastRoute = location;
    _onRouteChanged(location);
  }

  void dispose() {
    router.routerDelegate.removeListener(_listener);
  }
}

final routeStateBridgeProvider = Provider<RouteStateBridge>((ref) {
  final router = ref.read(routerProvider);
  final lifecycleManager = ref.read(streamLifecycleManagerProvider);
  final bridge = RouteStateBridge(
    router: router,
    onRouteChanged: lifecycleManager.updateRoute,
  );

  ref.onDispose(bridge.dispose);
  return bridge;
});
