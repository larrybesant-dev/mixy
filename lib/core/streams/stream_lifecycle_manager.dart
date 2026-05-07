import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StreamLifecycleManager extends ChangeNotifier {
  StreamLifecycleManager._internal();

  static final StreamLifecycleManager instance =
      StreamLifecycleManager._internal();

  factory StreamLifecycleManager() => instance;

  String _currentRoutePath = '/';
  final Map<String, int> _activeListenerCounts = <String, int>{};
  final Map<String, Stream<dynamic>> _sharedStreams =
      <String, Stream<dynamic>>{};
  bool _disposed = false;

  String get currentRoutePath => _currentRoutePath;

  void updateRoute(String routePath) {
    if (_disposed) return;
    final normalized = _normalizeRoute(routePath);
    if (_currentRoutePath == normalized) {
      return;
    }
    _currentRoutePath = normalized;
    notifyListeners();
  }

  bool isRouteActive(List<String> routePrefixes) {
    if (routePrefixes.isEmpty) {
      return true;
    }

    final path = _currentRoutePath;
    for (final prefix in routePrefixes) {
      final normalizedPrefix = _normalizeRoute(prefix);
      if (normalizedPrefix == '*') {
        return true;
      }
      if (path == normalizedPrefix || path.startsWith('$normalizedPrefix/')) {
        return true;
      }
    }
    return false;
  }

  Stream<T> bind<T>({
    required String key,
    required Stream<T> Function() create,
    List<String> routePrefixes = const <String>[],
  }) {
    if (!isRouteActive(routePrefixes)) {
      return Stream<T>.empty();
    }

    final scopedKey = _scopedStreamKey(key);
    final existing = _sharedStreams[scopedKey];
    if (existing != null) {
      return existing.cast<T>();
    }

    late final Stream<T> broadcast;
    broadcast = create().asBroadcastStream(
      onListen: (_) {
        _register(scopedKey);
      },
      onCancel: (_) {
        _unregister(scopedKey);
        _sharedStreams.remove(scopedKey);
      },
    );

    _sharedStreams[scopedKey] = broadcast;
    return broadcast;
  }

  String buildDedupeKey({
    required String domain,
    String? userId,
    String? route,
    String? queryHash,
  }) {
    final routePart = (route ?? _currentRoutePath).trim();
    final userPart = (userId ?? '*').trim();
    final queryPart = (queryHash ?? '*').trim();
    return '$domain|user=$userPart|route=$routePart|q=$queryPart';
  }

  String _scopedStreamKey(String key) => '$key@route=$_currentRoutePath';

  void _register(String key) {
    final nextCount = (_activeListenerCounts[key] ?? 0) + 1;
    _activeListenerCounts[key] = nextCount;
    if (kDebugMode && nextCount > 1) {
      developer.log(
        'Duplicate stream listener registered for $key on route $_currentRoutePath',
        name: 'StreamLifecycleManager',
        level: 900,
      );
    }
  }

  void _unregister(String key) {
    final currentCount = _activeListenerCounts[key];
    if (currentCount == null || currentCount <= 1) {
      _activeListenerCounts.remove(key);
      return;
    }
    _activeListenerCounts[key] = currentCount - 1;
  }

  static String _normalizeRoute(String routePath) {
    final trimmed = routePath.trim();
    if (trimmed.isEmpty) {
      return '/';
    }
    if (trimmed == '*') {
      return trimmed;
    }
    return trimmed.startsWith('/') ? trimmed : '/$trimmed';
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    super.dispose();
  }
}

final streamLifecycleManagerProvider =
    ChangeNotifierProvider<StreamLifecycleManager>((ref) {
      final manager = StreamLifecycleManager();
      ref.onDispose(manager.dispose);
      return manager;
    });
