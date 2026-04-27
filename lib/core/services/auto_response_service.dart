import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger.dart';
import '../telemetry/app_telemetry.dart';
import 'feature_gate_service.dart';

@immutable
class AutoResponseState {
  const AutoResponseState({
    this.messagingFailures5m = 0,
    this.roomJoinFailures5m = 0,
    this.authFailures5m = 0,
    this.messagingMode = FeatureServiceMode.full,
    this.roomsMode = FeatureServiceMode.full,
    this.authRecoveryRecommended = false,
    this.lastAction,
    this.lastActionAt,
  });

  final int messagingFailures5m;
  final int roomJoinFailures5m;
  final int authFailures5m;
  final FeatureServiceMode messagingMode;
  final FeatureServiceMode roomsMode;
  final bool authRecoveryRecommended;
  final String? lastAction;
  final DateTime? lastActionAt;

  AutoResponseState copyWith({
    int? messagingFailures5m,
    int? roomJoinFailures5m,
    int? authFailures5m,
    FeatureServiceMode? messagingMode,
    FeatureServiceMode? roomsMode,
    bool? authRecoveryRecommended,
    String? lastAction,
    DateTime? lastActionAt,
  }) {
    return AutoResponseState(
      messagingFailures5m: messagingFailures5m ?? this.messagingFailures5m,
      roomJoinFailures5m: roomJoinFailures5m ?? this.roomJoinFailures5m,
      authFailures5m: authFailures5m ?? this.authFailures5m,
      messagingMode: messagingMode ?? this.messagingMode,
      roomsMode: roomsMode ?? this.roomsMode,
      authRecoveryRecommended:
          authRecoveryRecommended ?? this.authRecoveryRecommended,
      lastAction: lastAction ?? this.lastAction,
      lastActionAt: lastActionAt ?? this.lastActionAt,
    );
  }
}

final autoResponseControllerProvider =
    StateNotifierProvider<AutoResponseController, AutoResponseState>((ref) {
      final controller = AutoResponseController(
        readFeatureGateController: () =>
            ref.read(featureGateControllerProvider.notifier),
      );
      controller.initialize();
      return controller;
    });

class AutoResponseController extends StateNotifier<AutoResponseState> {
  AutoResponseController({
    required FeatureGateController Function() readFeatureGateController,
  })  : _readFeatureGateController = readFeatureGateController,
        super(const AutoResponseState());

  static const Duration _window = Duration(minutes: 5);
  static const Duration _modeChangeCooldown = Duration(minutes: 2);
  static const Duration _recoveryStabilityWindow = Duration(minutes: 8);

  static const int _weightAuthFailure = 5;
  static const int _weightMessagingFailure = 3;
  static const int _weightRoomJoinFailure = 3;
  static const int _weightUiNoise = 1;

  final FeatureGateController Function() _readFeatureGateController;

  final List<DateTime> _messagingFailures = <DateTime>[];
  final List<DateTime> _roomJoinFailures = <DateTime>[];
  final List<DateTime> _authFailures = <DateTime>[];
  final List<DateTime> _uiNoise = <DateTime>[];

  DateTime? _messagingModeChangedAt;
  DateTime? _roomsModeChangedAt;
  DateTime? _messagingRecoveryStableSince;
  DateTime? _roomsRecoveryStableSince;
  DateTime? _authRecoveryStableSince;

  DateTime _lastProcessedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _initialized = false;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
    AppTelemetry.notifier.addListener(_onTelemetryChanged);
  }

  void _onTelemetryChanged() {
    final current = AppTelemetry.state;
    if (current.recentEvents.isEmpty) {
      return;
    }

    final fresh = current.recentEvents
        .where((event) => event.timestamp.isAfter(_lastProcessedAt))
        .toList(growable: false)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    if (fresh.isEmpty) {
      return;
    }

    for (final event in fresh) {
      _consumeEvent(event);
    }

    _lastProcessedAt = fresh.last.timestamp;
    _trimWindows();
    _applyRules();

    state = state.copyWith(
      messagingFailures5m: _messagingFailures.length,
      roomJoinFailures5m: _roomJoinFailures.length,
      authFailures5m: _authFailures.length,
    );
  }

  void _consumeEvent(TelemetryEvent event) {
    final now = event.timestamp;

    if (event.domain == 'messaging' &&
        event.action == 'send_message' &&
        (event.result == 'failure' || event.level == 'error')) {
      _messagingFailures.add(now);
      return;
    }

    if (event.domain == 'room' &&
        event.action == 'join' &&
        (event.result == 'failure' || event.level == 'error')) {
      _roomJoinFailures.add(now);
      return;
    }

    if (event.domain == 'auth' && event.level == 'error') {
      _authFailures.add(now);
      return;
    }

    if (event.domain == 'routing' && event.action == 'degraded_entry_event') {
      _uiNoise.add(now);
    }
  }

  void _trimWindows() {
    final cutoff = DateTime.now().subtract(_window);
    _messagingFailures.removeWhere((at) => at.isBefore(cutoff));
    _roomJoinFailures.removeWhere((at) => at.isBefore(cutoff));
    _authFailures.removeWhere((at) => at.isBefore(cutoff));
    _uiNoise.removeWhere((at) => at.isBefore(cutoff));
  }

  void _applyRules() {
    final gateController = _readFeatureGateController();
    final gates = gateController.state;
    final now = DateTime.now();

    final messagingRiskScore =
        (_messagingFailures.length * _weightMessagingFailure) +
        (_authFailures.length * _weightAuthFailure) +
        (_uiNoise.length * _weightUiNoise);

    final roomsRiskScore = (_roomJoinFailures.length * _weightRoomJoinFailure) +
        (_authFailures.length * _weightAuthFailure) +
        (_uiNoise.length * _weightUiNoise);

    final nextMessagingMode = _resolveModeWithHysteresis(
      feature: 'messaging',
      currentMode: state.messagingMode,
      riskScore: messagingRiskScore,
      degradedThresholdScore: 15,
      disabledThresholdScore: 24,
      recoverDisabledThresholdScore: 7,
      recoverFullThresholdScore: 2,
      now: now,
    );
    _applyFeatureModeIfChanged(
      feature: 'messaging',
      nextMode: nextMessagingMode,
      currentMode: state.messagingMode,
      gateController: gateController,
      trigger: 'weighted_messaging_risk',
      count5m: _messagingFailures.length,
      riskScore: messagingRiskScore,
      hasOperatorOverride: gates.operatorMessagingMode != null,
    );

    final nextRoomsMode = _resolveModeWithHysteresis(
      feature: 'rooms',
      currentMode: state.roomsMode,
      riskScore: roomsRiskScore,
      degradedThresholdScore: 18,
      disabledThresholdScore: 30,
      recoverDisabledThresholdScore: 8,
      recoverFullThresholdScore: 3,
      now: now,
    );
    _applyFeatureModeIfChanged(
      feature: 'rooms',
      nextMode: nextRoomsMode,
      currentMode: state.roomsMode,
      gateController: gateController,
      trigger: 'weighted_room_risk',
      count5m: _roomJoinFailures.length,
      riskScore: roomsRiskScore,
      hasOperatorOverride: gates.operatorLiveRoomsMode != null,
    );

    final shouldRecommendAuthRecovery = _authFailures.length >= 6;
    if (shouldRecommendAuthRecovery && !state.authRecoveryRecommended) {
      AppTelemetry.logAction(
        level: 'warning',
        domain: 'ops',
        action: 'kill_switch_trigger_event',
        message: 'Auto-response flagged auth session recovery recommendation.',
        result: 'auth_recovery_recommended',
        metadata: <String, Object?>{
          'trigger': 'auth_failure_spike',
          'count_5m': _authFailures.length,
          'risk_score': _authFailures.length * _weightAuthFailure,
          'window_minutes': _window.inMinutes,
        },
      );
      state = state.copyWith(
        authRecoveryRecommended: true,
        lastAction: 'auth_recovery_recommended',
        lastActionAt: DateTime.now(),
      );
      Logger.warning(
        'Auto-response flagged auth session recovery recommendation count5m=${_authFailures.length}',
      );
    }

    if (!shouldRecommendAuthRecovery && state.authRecoveryRecommended) {
      _authRecoveryStableSince ??= now;
      if (now.difference(_authRecoveryStableSince!) >= _recoveryStabilityWindow) {
        state = state.copyWith(authRecoveryRecommended: false);
        _authRecoveryStableSince = null;
      }
    } else if (shouldRecommendAuthRecovery) {
      _authRecoveryStableSince = null;
    }
  }

  FeatureServiceMode _resolveModeWithHysteresis({
    required String feature,
    required FeatureServiceMode currentMode,
    required int riskScore,
    required int degradedThresholdScore,
    required int disabledThresholdScore,
    required int recoverDisabledThresholdScore,
    required int recoverFullThresholdScore,
    required DateTime now,
  }) {
    if (riskScore >= disabledThresholdScore) {
      return FeatureServiceMode.disabled;
    }
    if (riskScore >= degradedThresholdScore) {
      return FeatureServiceMode.degraded;
    }

    final lastChangedAt = feature == 'messaging'
        ? _messagingModeChangedAt
        : _roomsModeChangedAt;
    final inCooldown =
        lastChangedAt != null && now.difference(lastChangedAt) < _modeChangeCooldown;

    if (inCooldown) {
      return currentMode;
    }

    if (currentMode == FeatureServiceMode.disabled) {
      if (riskScore <= recoverDisabledThresholdScore) {
        if (_markRecoveryStability(feature: feature, now: now)) {
          return FeatureServiceMode.degraded;
        }
      } else {
        _clearRecoveryStability(feature: feature);
      }
      return currentMode;
    }

    if (currentMode == FeatureServiceMode.degraded) {
      if (riskScore <= recoverFullThresholdScore) {
        if (_markRecoveryStability(feature: feature, now: now)) {
          return FeatureServiceMode.full;
        }
      } else {
        _clearRecoveryStability(feature: feature);
      }
      return currentMode;
    }

    _clearRecoveryStability(feature: feature);
    return FeatureServiceMode.full;
  }

  bool _markRecoveryStability({
    required String feature,
    required DateTime now,
  }) {
    if (feature == 'messaging') {
      _messagingRecoveryStableSince ??= now;
      return now.difference(_messagingRecoveryStableSince!) >=
          _recoveryStabilityWindow;
    }

    _roomsRecoveryStableSince ??= now;
    return now.difference(_roomsRecoveryStableSince!) >=
        _recoveryStabilityWindow;
  }

  void _clearRecoveryStability({required String feature}) {
    if (feature == 'messaging') {
      _messagingRecoveryStableSince = null;
      return;
    }
    _roomsRecoveryStableSince = null;
  }

  void _applyFeatureModeIfChanged({
    required String feature,
    required FeatureServiceMode nextMode,
    required FeatureServiceMode currentMode,
    required FeatureGateController gateController,
    required String trigger,
    required int count5m,
    required int riskScore,
    required bool hasOperatorOverride,
  }) {
    if (nextMode == currentMode) {
      return;
    }

    if (hasOperatorOverride) {
      AppTelemetry.logAction(
        level: 'info',
        domain: 'ops',
        action: 'kill_switch_trigger_event',
        message: 'Auto-response skipped mode change because operator override is active.',
        result: '$feature:skipped_operator_override',
        metadata: <String, Object?>{
          'trigger': trigger,
          'risk_score': riskScore,
          'count_5m': count5m,
        },
      );
      return;
    }

    gateController.setLocalFeatureMode(
      feature: feature,
      mode: nextMode,
      source: 'auto-response',
    );

    AppTelemetry.logAction(
      level: nextMode == FeatureServiceMode.disabled ? 'error' : 'warning',
      domain: 'ops',
      action: 'kill_switch_trigger_event',
      message: 'Auto-response changed feature mode.',
      result: '$feature:${nextMode.name}',
      metadata: <String, Object?>{
        'trigger': trigger,
        'count_5m': count5m,
        'risk_score': riskScore,
        'window_minutes': _window.inMinutes,
      },
    );

    final now = DateTime.now();
    if (feature == 'messaging') {
      _messagingModeChangedAt = now;
      state = state.copyWith(
        messagingMode: nextMode,
        lastAction: '$feature:${nextMode.name}',
        lastActionAt: now,
      );
      return;
    }

    _roomsModeChangedAt = now;
    state = state.copyWith(
      roomsMode: nextMode,
      lastAction: '$feature:${nextMode.name}',
      lastActionAt: now,
    );
  }

  @override
  void dispose() {
    AppTelemetry.notifier.removeListener(_onTelemetryChanged);
    super.dispose();
  }
}
