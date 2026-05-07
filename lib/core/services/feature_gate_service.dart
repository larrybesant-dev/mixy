import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger.dart';

enum FeatureServiceMode { full, disabled }

@immutable
class FeatureGateState {
  const FeatureGateState({
    required this.enableLiveRooms,
    required this.enableMessaging,
    required this.enableSpeedDating,
    required this.enablePushNotifications,
    required this.feedRefreshRateSeconds,
    required this.lastUpdatedAt,
    required this.source,
  });

  const FeatureGateState.defaults()
    : enableLiveRooms = true,
      enableMessaging = true,
      enableSpeedDating = true,
      enablePushNotifications = true,
      feedRefreshRateSeconds = 30,
      lastUpdatedAt = null,
      source = 'beta-default';

  final bool enableLiveRooms;
  final bool enableMessaging;
  final bool enableSpeedDating;
  final bool enablePushNotifications;
  final int feedRefreshRateSeconds;
  final DateTime? lastUpdatedAt;
  final String source;

  FeatureServiceMode get liveRoomsMode =>
      enableLiveRooms ? FeatureServiceMode.full : FeatureServiceMode.disabled;

  FeatureServiceMode get messagingMode =>
      enableMessaging ? FeatureServiceMode.full : FeatureServiceMode.disabled;

  FeatureServiceMode get speedDatingMode =>
      enableSpeedDating ? FeatureServiceMode.full : FeatureServiceMode.disabled;

  FeatureServiceMode get pushNotificationsMode => enablePushNotifications
      ? FeatureServiceMode.full
      : FeatureServiceMode.disabled;

  bool get liveRoomsDegraded => false;
  bool get messagingDegraded => false;
  bool get hasLocalOverrides => false;
  bool get hasOperatorOverrides => false;
  bool get remoteEnableLiveRooms => enableLiveRooms;
  bool get remoteEnableMessaging => enableMessaging;
  bool get remoteEnableSpeedDating => enableSpeedDating;
  bool get remoteEnablePushNotifications => enablePushNotifications;
  int get remoteFeedRefreshRate => feedRefreshRateSeconds;
  String? get localOverrideSource => null;
  DateTime? get localOverrideUpdatedAt => null;
  FeatureServiceMode? get operatorLiveRoomsMode => null;
  FeatureServiceMode? get operatorMessagingMode => null;
  String? get operatorOverrideSource => null;
  DateTime? get operatorOverrideUpdatedAt => null;

  FeatureGateState copyWith({
    bool? enableLiveRooms,
    bool? enableMessaging,
    bool? enableSpeedDating,
    bool? enablePushNotifications,
    int? feedRefreshRateSeconds,
    DateTime? lastUpdatedAt,
    String? source,
  }) {
    return FeatureGateState(
      enableLiveRooms: enableLiveRooms ?? this.enableLiveRooms,
      enableMessaging: enableMessaging ?? this.enableMessaging,
      enableSpeedDating: enableSpeedDating ?? this.enableSpeedDating,
      enablePushNotifications:
          enablePushNotifications ?? this.enablePushNotifications,
      feedRefreshRateSeconds:
          feedRefreshRateSeconds ?? this.feedRefreshRateSeconds,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      source: source ?? this.source,
    );
  }
}

final featureGateControllerProvider =
    StateNotifierProvider<FeatureGateController, FeatureGateState>((ref) {
      final controller = FeatureGateController();
      unawaited(controller.initialize());
      return controller;
    });

class FeatureGateController extends StateNotifier<FeatureGateState> {
  FeatureGateController() : super(const FeatureGateState.defaults());

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    state = state.copyWith(
      enableLiveRooms: true,
      enableMessaging: true,
      enableSpeedDating: true,
      enablePushNotifications: true,
      feedRefreshRateSeconds: 30,
      lastUpdatedAt: DateTime.now(),
      source: 'beta-runtime-defaults',
    );
  }

  Future<void> refreshNow({String source = 'manual-refresh'}) async {
    state = state.copyWith(lastUpdatedAt: DateTime.now(), source: source);
  }

  void setFeatureEnabled({
    required String feature,
    required bool enabled,
    String source = 'beta-manual',
  }) {
    switch (feature) {
      case 'rooms':
        state = state.copyWith(
          enableLiveRooms: enabled,
          lastUpdatedAt: DateTime.now(),
          source: source,
        );
        break;
      case 'messaging':
        state = state.copyWith(
          enableMessaging: enabled,
          lastUpdatedAt: DateTime.now(),
          source: source,
        );
        break;
      case 'speed_dating':
        state = state.copyWith(
          enableSpeedDating: enabled,
          lastUpdatedAt: DateTime.now(),
          source: source,
        );
        break;
      case 'push_notifications':
        state = state.copyWith(
          enablePushNotifications: enabled,
          lastUpdatedAt: DateTime.now(),
          source: source,
        );
        break;
      default:
        Logger.warning('Unknown feature gate toggle target: $feature');
        return;
    }

    Logger.info(
      'Feature gate updated feature=$feature enabled=$enabled source=$source',
    );
  }

  void setLocalFeatureMode({
    required String feature,
    required FeatureServiceMode mode,
    String source = 'local-override',
  }) {
    setFeatureEnabled(
      feature: feature,
      enabled: mode != FeatureServiceMode.disabled,
      source: source,
    );
  }

  void clearLocalFeatureModes({String source = 'local-override-cleared'}) {
    state = state.copyWith(
      enableLiveRooms: true,
      enableMessaging: true,
      enableSpeedDating: true,
      enablePushNotifications: true,
      feedRefreshRateSeconds: 30,
      lastUpdatedAt: DateTime.now(),
      source: source,
    );
    Logger.info('Feature gate local overrides cleared source=$source');
  }

  void setOperatorFeatureMode({
    required String feature,
    required FeatureServiceMode mode,
    String source = 'operator',
  }) {
    setFeatureEnabled(
      feature: feature,
      enabled: mode != FeatureServiceMode.disabled,
      source: source,
    );
  }

  void clearOperatorFeatureModes({String source = 'operator-cleared'}) {
    clearLocalFeatureModes(source: source);
    Logger.info('Feature gate operator overrides cleared source=$source');
  }
}
