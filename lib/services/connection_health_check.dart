import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'diagnostic_logger.dart';

/// **Connection Health Check Service**
///
/// Proactively monitors signaling server health by:
/// 1. Periodic pings to Firestore (every 5 seconds)
/// 2. Latency tracking and trend analysis
/// 3. Preventive warnings before connection degrades
/// 4. Circuit breaker pattern (stops pinging if server unavailable)
///
/// **Why this matters:**
/// - Detects degraded connections *before* WebRTC/media fails
/// - Allows proactive UI warnings ("Your connection is unstable")
/// - Prevents cascading failures during poor network conditions
/// - Enables cost savings (don't wait 14s for recovery if degradation detected)
///
/// **Architecture:**
/// ```
/// HealthCheckService (manages pings, latency tracking)
///        ↓
/// connectionHealthProvider (Riverpod state: isHealthy, latencyMs, trend)
///        ↓
/// LiveRoomScreen (conditionally show warning badge)
/// ```
class ConnectionHealthCheckService with DiagnosticLogger {
  final FirebaseFirestore _firestore;

  // Configuration
  static const int _pingIntervalMs = 5000;      // Ping every 5 seconds
  static const int _latencyThresholdMs = 1000;  // >1s = degraded
  static const int _historySizeBytes = 10;      // Track last 10 pings for trend

  // State
  Timer? _pingTimer;
  final List<int> _latencyHistory = [];
  ConnectionHealth _currentHealth = ConnectionHealth.healthy;
  bool _circuitBreakerOpen = false;

  // Callback for state changes (wired to Riverpod)
  void Function(ConnectionHealth)? onHealthChanged;

  ConnectionHealthCheckService(this._firestore);

  /// Start health monitoring.
  void startMonitoring() {
    if (_pingTimer?.isActive ?? false) {
      logWarning('Health monitoring already active');
      return;
    }

    logInfo('Health monitoring started', metadata: {
      'pingIntervalMs': _pingIntervalMs,
      'latencyThresholdMs': _latencyThresholdMs,
    });

    _pingTimer = Timer.periodic(Duration(milliseconds: _pingIntervalMs), (_) {
      _performHealthCheck();
    });

    // Perform immediate health check
    _performHealthCheck();
  }

  /// Stop health monitoring and cleanup.
  void stopMonitoring() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _latencyHistory.clear();
    _circuitBreakerOpen = false;
    logInfo('Health monitoring stopped');
  }

  /// Single health check ping: measure latency to Firestore.
  Future<void> _performHealthCheck() async {
    if (_circuitBreakerOpen) {
      logWarning('Circuit breaker is open, skipping health check');
      return;
    }

    try {
      // Ping: Read a lightweight marker doc (like auth user doc or a shared health check doc)
      final stopwatch = Stopwatch()..start();

      await _firestore
          .collection('_health')
          .doc('signaling_server')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 5));

      stopwatch.stop();
      final latencyMs = stopwatch.elapsedMilliseconds;

      // Track latency
      _latencyHistory.add(latencyMs);
      if (_latencyHistory.length > _historySizeBytes) {
        _latencyHistory.removeAt(0);
      }

      // Determine health status
      final newHealth = _analyzeHealth(latencyMs);
      if (newHealth != _currentHealth) {
        _currentHealth = newHealth;
        onHealthChanged?.call(newHealth);

        logInfo('Health status changed', metadata: {
          'from': _currentHealth.toString(),
          'to': newHealth.toString(),
          'latencyMs': latencyMs,
        });
      }

      logInfo('Health check ping', metadata: {
        'latencyMs': latencyMs,
        'status': _currentHealth.toString(),
        'averageLatency': _calculateAverageLatency(),
      });
    } catch (e) {
      logError('Health check failed', error: e, metadata: {
        'averageLatency': _calculateAverageLatency(),
      });

      // Open circuit breaker after 3 consecutive failures
      if (_latencyHistory.length >= 3 &&
          _latencyHistory.sublist(_latencyHistory.length - 3).every((l) => l > _latencyThresholdMs)) {
        _circuitBreakerOpen = true;
        logCritical('Circuit breaker opened, halting health checks', error: e);
        _updateHealth(ConnectionHealth.unavailable);
      }
    }
  }

  /// Analyze health based on latency and trend.
  ConnectionHealth _analyzeHealth(int latencyMs) {
    // Single ping > threshold: degraded
    if (latencyMs > _latencyThresholdMs) {
      return ConnectionHealth.degraded;
    }

    // All recent pings healthy: check trend
    if (_latencyHistory.length >= _historySizeBytes) {
      final average = _calculateAverageLatency();
      if (average > _latencyThresholdMs * 0.7) {
        return ConnectionHealth.degrading; // Trending upward
      }
    }

    return ConnectionHealth.healthy;
  }

  /// Calculate average latency from history.
  int _calculateAverageLatency() {
    if (_latencyHistory.isEmpty) return 0;
    return (_latencyHistory.reduce((a, b) => a + b) / _latencyHistory.length).round();
  }

  /// Update health status and notify listeners.
  void _updateHealth(ConnectionHealth newHealth) {
    if (newHealth != _currentHealth) {
      _currentHealth = newHealth;
      onHealthChanged?.call(newHealth);
    }
  }

  /// Get current health status.
  ConnectionHealth get health => _currentHealth;

  /// Get average latency (for UI display).
  int get averageLatency => _calculateAverageLatency();

  /// Get latency history (for debugging/charts).
  List<int> get latencyHistory => List.unmodifiable(_latencyHistory);

  /// Get circuit breaker status.
  bool get isCircuitBreakerOpen => _circuitBreakerOpen;
}

/// Health status enum.
enum ConnectionHealth {
  /// ✅ Latency < 1s, no degradation trend
  healthy,

  /// ⚠️ Latency 1-2s or trending upward
  degrading,

  /// 🔴 Latency > 2s or multiple consecutive failures
  degraded,

  /// ❌ Server unreachable, circuit breaker open
  unavailable;

  /// Human-readable status for UI display.
  String get displayName {
    switch (this) {
      case ConnectionHealth.healthy:
        return 'Healthy';
      case ConnectionHealth.degrading:
        return 'Degrading';
      case ConnectionHealth.degraded:
        return 'Degraded';
      case ConnectionHealth.unavailable:
        return 'Unavailable';
    }
  }

  /// Icon asset path for UI badges.
  String get iconPath {
    switch (this) {
      case ConnectionHealth.healthy:
        return 'assets/icons/connection_healthy.svg';
      case ConnectionHealth.degrading:
        return 'assets/icons/connection_warning.svg';
      case ConnectionHealth.degraded:
        return 'assets/icons/connection_error.svg';
      case ConnectionHealth.unavailable:
        return 'assets/icons/connection_offline.svg';
    }
  }
}

/// **Riverpod Provider: Connection Health State**
///
/// Exposes connection health to UI layer. Integrates with Riverpod's reactive system.
///
/// **Usage:**
/// ```dart
/// final health = ref.watch(connectionHealthProvider);
/// if (health.health == ConnectionHealth.degrading) {
///   // Show warning badge
/// }
/// ```
final connectionHealthServiceProvider = Provider.autoDispose<ConnectionHealthCheckService>((ref) {
  final service = ConnectionHealthCheckService(FirebaseFirestore.instance);

  // Start monitoring when provider is first accessed
  service.startMonitoring();

  // Stop monitoring when provider is disposed (no longer watched)
  ref.onDispose(() {
    service.stopMonitoring();
  });

  return service;
});

/// **Riverpod State Notifier: Health Status + Latency**
class ConnectionHealthNotifier extends StateNotifier<ConnectionHealthState> {
  final ConnectionHealthCheckService _service;

  ConnectionHealthNotifier(this._service)
      : super(const ConnectionHealthState(
          health: ConnectionHealth.healthy,
          averageLatency: 0,
          lastPingTime: null,
        )) {
    // Wire service callbacks to Riverpod state updates
    _service.onHealthChanged = (newHealth) {
      state = state.copyWith(
        health: newHealth,
        lastPingTime: DateTime.now(),
      );
    };

    // Update latency periodically
    _startLatencyUpdater();
  }

  void _startLatencyUpdater() {
    Timer.periodic(const Duration(seconds: 1), (_) {
      state = state.copyWith(averageLatency: _service.averageLatency);
    });
  }

  @override
  void dispose() {
    _service.stopMonitoring();
    super.dispose();
  }
}

/// **Riverpod State: Health data**
final connectionHealthProvider = StateNotifierProvider.autoDispose<ConnectionHealthNotifier, ConnectionHealthState>(
  (ref) {
    final service = ref.watch(connectionHealthServiceProvider);
    return ConnectionHealthNotifier(service);
  },
);

/// Immutable state holder for health data.
class ConnectionHealthState {
  final ConnectionHealth health;
  final int averageLatency;
  final DateTime? lastPingTime;

  const ConnectionHealthState({
    required this.health,
    required this.averageLatency,
    this.lastPingTime,
  });

  /// Copy with optional field updates.
  ConnectionHealthState copyWith({
    ConnectionHealth? health,
    int? averageLatency,
    DateTime? lastPingTime,
  }) =>
      ConnectionHealthState(
        health: health ?? this.health,
        averageLatency: averageLatency ?? this.averageLatency,
        lastPingTime: lastPingTime ?? this.lastPingTime,
      );

  /// Check if connection is at risk (degrading or worse).
  bool get isAtRisk => health.index >= ConnectionHealth.degrading.index;

  /// Human-readable status with latency.
  String get displayStatus => '${health.displayName} (${averageLatency}ms)';
}
