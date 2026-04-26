import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../logger.dart';

const String kEnableLiveRoomsKey = 'enable_live_rooms';
const String kEnableMessagingKey = 'enable_messaging';

@immutable
class FeatureGateState {
  const FeatureGateState({
    required this.enableLiveRooms,
    required this.enableMessaging,
    required this.lastUpdatedAt,
    required this.source,
  });

  const FeatureGateState.defaults()
      : enableLiveRooms = true,
        enableMessaging = true,
        lastUpdatedAt = null,
        source = 'local-defaults';

  final bool enableLiveRooms;
  final bool enableMessaging;
  final DateTime? lastUpdatedAt;
  final String source;

  FeatureGateState copyWith({
    bool? enableLiveRooms,
    bool? enableMessaging,
    DateTime? lastUpdatedAt,
    String? source,
  }) {
    return FeatureGateState(
      enableLiveRooms: enableLiveRooms ?? this.enableLiveRooms,
      enableMessaging: enableMessaging ?? this.enableMessaging,
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
      enableLiveRooms: enableLiveRooms,
      enableMessaging: enableMessaging,
      lastUpdatedAt: DateTime.now(),
      source: source,
    );

    Logger.info(
      'Feature gates updated liveRooms=$enableLiveRooms messaging=$enableMessaging source=$source',
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _updateSubscription?.cancel();
    super.dispose();
  }
}
