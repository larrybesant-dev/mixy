import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/telemetry/telemetry_config.dart';
import 'production_alerts.dart';
import 'runtime_telemetry.dart';

/// Riverpod [ProviderObserver] that feeds lifecycle events into
/// [RuntimeTelemetry] and [ProductionAlertSystem].
///
/// Only active in debug mode — in release builds all methods are no-ops so
/// there is zero overhead in production.
final class MixvyProviderObserver extends ProviderObserver {
  /// Rebuild count threshold within [_burstWindowSeconds] that fires a
  /// WARNING alert.
  static const int _warnThreshold = 30;

  /// Rebuild count threshold within [_burstWindowSeconds] that fires a
  /// CRITICAL alert.
  static const int _criticalThreshold = 60;

  /// Window in seconds over which burst counts are evaluated.
  static const int _burstWindowSeconds = 5;

  /// Tracks first-rebuild timestamps per provider name for burst detection.
  final Map<String, DateTime> _burstWindowStart = {};

  /// Burst counts within the current window per provider.
  final Map<String, int> _burstCounts = {};

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    if (!TelemetryConfig.isActive) return;

    final name = _nameOf(provider);
    RuntimeTelemetry.recordRebuild(name);
    _checkBurst(name);
  }

  @override
  void didAddProvider(
    ProviderBase<Object?> provider,
    Object? value,
    ProviderContainer container,
  ) {
    if (!TelemetryConfig.isActive) return;
    RuntimeTelemetry.registerListener(_nameOf(provider));
  }

  @override
  void didDisposeProvider(
    ProviderBase<Object?> provider,
    ProviderContainer container,
  ) {
    if (!TelemetryConfig.isActive) return;
    final name = _nameOf(provider);
    RuntimeTelemetry.unregisterListener(name);
    _burstWindowStart.remove(name);
    _burstCounts.remove(name);
  }

  // ─── Burst detection ───────────────────────────────────────────────────────

  void _checkBurst(String name) {
    final now = DateTime.now();
    final windowStart = _burstWindowStart[name];

    if (windowStart == null ||
        now.difference(windowStart).inSeconds >= _burstWindowSeconds) {
      // Start a fresh window.
      _burstWindowStart[name] = now;
      _burstCounts[name] = 1;
      return;
    }

    final count = (_burstCounts[name] ?? 0) + 1;
    _burstCounts[name] = count;

    if (count == _criticalThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'hot_provider_critical_$name',
        message: 'HOT PROVIDER [$name]: $count rebuilds in ${_burstWindowSeconds}s',
        level: AlertLevel.critical,
      );
      debugPrint(
        '[MixvyObserver] 🔴 HOT PROVIDER: $name — $count rebuilds/${_burstWindowSeconds}s',
      );
    } else if (count == _warnThreshold) {
      ProductionAlertSystem.fireCustomAlert(
        id: 'hot_provider_warn_$name',
        message: 'Frequent provider [$name]: $count rebuilds in ${_burstWindowSeconds}s',
        level: AlertLevel.warning,
      );
      debugPrint(
        '[MixvyObserver] 🟡 FREQUENT PROVIDER: $name — $count rebuilds/${_burstWindowSeconds}s',
      );
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  static String _nameOf(ProviderBase<Object?> provider) =>
      provider.name ?? provider.runtimeType.toString();
}
