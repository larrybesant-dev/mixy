import 'package:flutter/foundation.dart';

/// Controls the verbosity level of all telemetry systems in MixVy.
///
/// * [off]      — no telemetry. Zero overhead. Default in release builds.
/// * [standard] — counters, threshold alerts, session summaries only.
///                Safe for production debug builds. Default in debug builds.
/// * [debug]    — full event tracing including per-event prints and ICE logs.
///                Developer / QA sessions only.
enum TelemetryMode { off, standard, debug }

/// Tier applied to individual telemetry call sites.
///
/// * [critical]    — disconnect / failure / peer-down events.
///                   Emitted in [TelemetryMode.standard] and [TelemetryMode.debug].
/// * [operational] — threshold alerts, burst warnings, session summaries.
///                   Emitted in [TelemetryMode.standard] and [TelemetryMode.debug].
/// * [debug]       — per-event prints, ICE logs, rebuild counts.
///                   Emitted only in [TelemetryMode.debug].
enum LogTier { critical, operational, debug }

/// Single source of truth for telemetry mode across all observability layers.
///
/// ### Initialization (call once in `main()`, before `runApp`):
/// ```dart
/// TelemetryConfig.initialize();               // auto-selects based on build
/// TelemetryConfig.initialize(TelemetryMode.debug); // force a specific mode
/// ```
///
/// ### Runtime override (no rebuild required):
/// ```dart
/// TelemetryConfig.setRuntimeOverride(TelemetryMode.debug);
/// TelemetryConfig.clearRuntimeOverride(); // revert to build-level default
/// ```
abstract final class TelemetryConfig {
  static TelemetryMode _base = TelemetryMode.off;
  static TelemetryMode? _runtimeOverride;

  // ─── Mode accessors ────────────────────────────────────────────────────────

  /// Active mode: runtime override takes precedence over base.
  static TelemetryMode get mode => _runtimeOverride ?? _base;

  /// Whether any telemetry is active (any mode above [TelemetryMode.off]).
  static bool get isActive => mode != TelemetryMode.off;

  // ─── Initialization ────────────────────────────────────────────────────────

  /// Set the base mode for this build session.
  ///
  /// If [forcedMode] is omitted, defaults to:
  /// * [TelemetryMode.standard] in debug builds (`kDebugMode == true`)
  /// * [TelemetryMode.off] in release builds
  static void initialize([TelemetryMode? forcedMode]) {
    _base =
        forcedMode ?? (kDebugMode ? TelemetryMode.standard : TelemetryMode.off);
    _runtimeOverride = null;
  }

  // ─── Runtime override ──────────────────────────────────────────────────────

  /// Override the active mode at runtime without a rebuild or redeploy.
  ///
  /// Useful for enabling full debug tracing in a live debug session.
  static void setRuntimeOverride(TelemetryMode overrideMode) {
    _runtimeOverride = overrideMode;
  }

  /// Remove any runtime override, reverting to the build-level base mode.
  static void clearRuntimeOverride() {
    _runtimeOverride = null;
  }

  // ─── Tier gate ─────────────────────────────────────────────────────────────

  /// Returns `true` if events at [tier] should be processed in the current mode.
  ///
  /// Use this at every call site to gate logging and event emission:
  /// ```dart
  /// if (TelemetryConfig.allows(LogTier.operational)) {
  ///   debugPrint('[MySystem] threshold crossed');
  /// }
  /// ```
  static bool allows(LogTier tier) {
    switch (mode) {
      case TelemetryMode.off:
        return false;
      case TelemetryMode.standard:
        return tier == LogTier.critical || tier == LogTier.operational;
      case TelemetryMode.debug:
        return true;
    }
  }
}



