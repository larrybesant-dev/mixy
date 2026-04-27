import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger.dart';

const String kEnableLiveRoomsKey = 'enable_live_rooms';
const String kEnableMessagingKey = 'enable_messaging';

enum FeatureServiceMode {
  full,
  degraded,
  disabled,
}

const Object _featureGateUnset = Object();

@immutable
class FeatureGateState {
  const FeatureGateState({
    required this.remoteEnableLiveRooms,
    required this.remoteEnableMessaging,
    required this.localLiveRoomsMode,
    required this.localMessagingMode,
    required this.lastUpdatedAt,
    required this.source,
    required this.localOverrideSource,
    required this.localOverrideUpdatedAt,
    required this.operatorLiveRoomsMode,
    required this.operatorMessagingMode,
    required this.operatorOverrideSource,
    required this.operatorOverrideUpdatedAt,
  });

  const FeatureGateState.defaults()
      : remoteEnableLiveRooms = true,
        remoteEnableMessaging = true,
        localLiveRoomsMode = FeatureServiceMode.full,
        localMessagingMode = FeatureServiceMode.full,
        lastUpdatedAt = null,
        source = 'local-defaults',
        localOverrideSource = null,
        localOverrideUpdatedAt = null,
        operatorLiveRoomsMode = null,
        operatorMessagingMode = null,
        operatorOverrideSource = null,
        operatorOverrideUpdatedAt = null;

  final bool remoteEnableLiveRooms;
  final bool remoteEnableMessaging;
  final FeatureServiceMode localLiveRoomsMode;
  final FeatureServiceMode localMessagingMode;
  final DateTime? lastUpdatedAt;
  final String source;
  final String? localOverrideSource;
  final DateTime? localOverrideUpdatedAt;
  final FeatureServiceMode? operatorLiveRoomsMode;
  final FeatureServiceMode? operatorMessagingMode;
  final String? operatorOverrideSource;
  final DateTime? operatorOverrideUpdatedAt;

  FeatureServiceMode get liveRoomsMode {
    if (operatorLiveRoomsMode != null) {
      return operatorLiveRoomsMode!;
    }
    if (!remoteEnableLiveRooms) {
      return FeatureServiceMode.disabled;
    }
    return localLiveRoomsMode;
  }

  FeatureServiceMode get messagingMode {
    if (operatorMessagingMode != null) {
      return operatorMessagingMode!;
    }
    if (!remoteEnableMessaging) {
      return FeatureServiceMode.disabled;
    }
    return localMessagingMode;
  }

  bool get enableLiveRooms => liveRoomsMode != FeatureServiceMode.disabled;
  bool get enableMessaging => messagingMode != FeatureServiceMode.disabled;

  bool get liveRoomsDegraded => liveRoomsMode == FeatureServiceMode.degraded;
  bool get messagingDegraded => messagingMode == FeatureServiceMode.degraded;

  bool get hasLocalOverrides =>
      localLiveRoomsMode != FeatureServiceMode.full ||
      localMessagingMode != FeatureServiceMode.full;

    bool get hasOperatorOverrides =>
      operatorLiveRoomsMode != null || operatorMessagingMode != null;

  FeatureGateState copyWith({
    bool? remoteEnableLiveRooms,
    bool? remoteEnableMessaging,
    FeatureServiceMode? localLiveRoomsMode,
    FeatureServiceMode? localMessagingMode,
    DateTime? lastUpdatedAt,
    String? source,
    String? localOverrideSource,
    DateTime? localOverrideUpdatedAt,
    Object? operatorLiveRoomsMode = _featureGateUnset,
    Object? operatorMessagingMode = _featureGateUnset,
    Object? operatorOverrideSource = _featureGateUnset,
    Object? operatorOverrideUpdatedAt = _featureGateUnset,
  }) {
    return FeatureGateState(
      remoteEnableLiveRooms: remoteEnableLiveRooms ?? this.remoteEnableLiveRooms,
      remoteEnableMessaging: remoteEnableMessaging ?? this.remoteEnableMessaging,
      localLiveRoomsMode: localLiveRoomsMode ?? this.localLiveRoomsMode,
      localMessagingMode: localMessagingMode ?? this.localMessagingMode,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      source: source ?? this.source,
      localOverrideSource: localOverrideSource ?? this.localOverrideSource,
      localOverrideUpdatedAt:
          localOverrideUpdatedAt ?? this.localOverrideUpdatedAt,
          operatorLiveRoomsMode: identical(operatorLiveRoomsMode, _featureGateUnset)
            ? this.operatorLiveRoomsMode
            : operatorLiveRoomsMode as FeatureServiceMode?,
          operatorMessagingMode: identical(operatorMessagingMode, _featureGateUnset)
            ? this.operatorMessagingMode
            : operatorMessagingMode as FeatureServiceMode?,
          operatorOverrideSource: identical(operatorOverrideSource, _featureGateUnset)
            ? this.operatorOverrideSource
            : operatorOverrideSource as String?,
          operatorOverrideUpdatedAt:
            identical(operatorOverrideUpdatedAt, _featureGateUnset)
            ? this.operatorOverrideUpdatedAt
            : operatorOverrideUpdatedAt as DateTime?,
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
  FeatureGateController({FirebaseRemoteConfig? remoteConfig})
      : _remoteConfig = remoteConfig,
        super(const FeatureGateState.defaults());

  FirebaseRemoteConfig? _remoteConfig;
  Timer? _refreshTimer;
  StreamSubscription<RemoteConfigUpdate>? _updateSubscription;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    try {
      _remoteConfig ??= FirebaseRemoteConfig.instance;

      await _remoteConfig!.setDefaults(<String, dynamic>{
        kEnableLiveRoomsKey: true,
        kEnableMessagingKey: true,
      });

      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 8),
          minimumFetchInterval: kDebugMode
              ? const Duration(seconds: 20)
              : const Duration(minutes: 1),
        ),
      );

      await refreshNow(source: 'startup-fetch');

      _updateSubscription?.cancel();
      _updateSubscription = _remoteConfig!.onConfigUpdated.listen((_) async {
        try {
          await _remoteConfig!.activate();
          _applyCurrentRemoteValues(source: 'realtime-update');
        } catch (error, stackTrace) {
          Logger.warning(
            'Feature gate realtime update failed',
            error: error,
            stackTrace: stackTrace,
          );
        }
      });

      _refreshTimer?.cancel();
      _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        unawaited(refreshNow(source: 'periodic-fetch'));
      });
    } catch (error, stackTrace) {
      Logger.warning(
        'Feature gates falling back to local defaults',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> refreshNow({String source = 'manual-refresh'}) async {
    final rc = _remoteConfig;
    if (rc == null) {
      return;
    }

    try {
      await rc.fetchAndActivate();
      _applyCurrentRemoteValues(source: source);
    } catch (error, stackTrace) {
      Logger.warning(
        'Feature gate refresh failed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void _applyCurrentRemoteValues({required String source}) {
    final rc = _remoteConfig;
    if (rc == null) {
      return;
    }

    final enableLiveRooms = rc.getBool(kEnableLiveRoomsKey);
    final enableMessaging = rc.getBool(kEnableMessagingKey);

    state = state.copyWith(
      remoteEnableLiveRooms: enableLiveRooms,
      remoteEnableMessaging: enableMessaging,
      lastUpdatedAt: DateTime.now(),
      source: source,
    );

    Logger.info(
      'Feature gates updated liveRooms=$enableLiveRooms messaging=$enableMessaging source=$source',
    );
  }

  void setLocalFeatureMode({
    required String feature,
    required FeatureServiceMode mode,
    String source = 'local-override',
  }) {
    switch (feature) {
      case 'messaging':
        state = state.copyWith(
          localMessagingMode: mode,
          localOverrideSource: source,
          localOverrideUpdatedAt: DateTime.now(),
        );
        Logger.warning(
          'Feature gate local override messagingMode=${mode.name} source=$source',
        );
        break;
      case 'rooms':
        state = state.copyWith(
          localLiveRoomsMode: mode,
          localOverrideSource: source,
          localOverrideUpdatedAt: DateTime.now(),
        );
        Logger.warning(
          'Feature gate local override roomsMode=${mode.name} source=$source',
        );
        break;
      default:
        Logger.warning('Unknown feature gate override target: $feature');
        return;
    }
  }

  void clearLocalFeatureModes({String source = 'local-override-cleared'}) {
    state = state.copyWith(
      localMessagingMode: FeatureServiceMode.full,
      localLiveRoomsMode: FeatureServiceMode.full,
      localOverrideSource: source,
      localOverrideUpdatedAt: DateTime.now(),
    );
    Logger.info('Feature gate local overrides cleared source=$source');
  }

  void setOperatorFeatureMode({
    required String feature,
    required FeatureServiceMode mode,
    String source = 'operator',
  }) {
    switch (feature) {
      case 'messaging':
        state = state.copyWith(
          operatorMessagingMode: mode,
          operatorOverrideSource: source,
          operatorOverrideUpdatedAt: DateTime.now(),
        );
        Logger.warning(
          'Feature gate operator override messagingMode=${mode.name} source=$source',
        );
        break;
      case 'rooms':
        state = state.copyWith(
          operatorLiveRoomsMode: mode,
          operatorOverrideSource: source,
          operatorOverrideUpdatedAt: DateTime.now(),
        );
        Logger.warning(
          'Feature gate operator override roomsMode=${mode.name} source=$source',
        );
        break;
      default:
        Logger.warning('Unknown feature gate operator override target: $feature');
        return;
    }
  }

  void clearOperatorFeatureModes({String source = 'operator-cleared'}) {
    state = state.copyWith(
      operatorMessagingMode: null,
      operatorLiveRoomsMode: null,
      operatorOverrideSource: source,
      operatorOverrideUpdatedAt: DateTime.now(),
    );
    Logger.info('Feature gate operator overrides cleared source=$source');
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _updateSubscription?.cancel();
    super.dispose();
  }
}
