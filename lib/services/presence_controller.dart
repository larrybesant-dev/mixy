import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/firebase_providers.dart';
import '../core/telemetry/app_telemetry.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../models/presence_model.dart';
import 'rtdb_presence_service.dart';

// Presence write authority:
// - RTDB sessions are the only writer for live presence truth.
// - Cloud Function projects RTDB session truth into Firestore presence docs.
// - Client code must not write to global presence documents directly.

class PresenceControllerState {
  const PresenceControllerState({
    this.userId,
    this.status = UserStatus.offline,
    this.appState = PresenceAppState.unknown,
    this.inRoom,
  });

  final String? userId;
  final UserStatus status;
  final PresenceAppState appState;
  final String? inRoom;

  bool get isAuthenticated => (userId ?? '').trim().isNotEmpty;
  bool get isOnline => status != UserStatus.offline;

  PresenceControllerState copyWith({
    Object? userId = _unset,
    UserStatus? status,
    PresenceAppState? appState,
    Object? inRoom = _unset,
  }) {
    return PresenceControllerState(
      userId: identical(userId, _unset) ? this.userId : userId as String?,
      status: status ?? this.status,
      appState: appState ?? this.appState,
      inRoom: identical(inRoom, _unset) ? this.inRoom : inRoom as String?,
    );
  }
}

const Object _unset = Object();

final presenceControllerProvider =
    NotifierProvider<PresenceController, PresenceControllerState>(
      PresenceController.new,
    );

class PresenceController extends Notifier<PresenceControllerState>
    with WidgetsBindingObserver {
  // Web-safe heartbeat cadence. Presence consumers treat entries older than
  // roughly 30-60 seconds as stale, so keep writes comfortably inside that window.
  static const Duration heartbeatInterval = Duration(seconds: 20);

  Timer? _heartbeatTimer;
  AppLifecycleState _lifecycleState = AppLifecycleState.resumed;

  RtdbPresenceService get _rtdb => ref.read(rtdbPresenceServiceProvider);

  bool get _hasFirebaseApp {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  PresenceControllerState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      final disposingUserId = state.userId;
      if (disposingUserId != null && disposingUserId.trim().isNotEmpty) {
        unawaited(_rtdb.disconnect(disposingUserId));
      }
      WidgetsBinding.instance.removeObserver(this);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    });

    if (!_hasFirebaseApp) {
      return const PresenceControllerState(
        status: UserStatus.offline,
        appState: PresenceAppState.detached,
      );
    }

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      unawaited(_handleAuthChange(previous?.uid, next.uid));
    });

    final initialUid = ref.read(authControllerProvider).uid;
    final initialState = initialUid == null
        ? const PresenceControllerState(
            status: UserStatus.offline,
            appState: PresenceAppState.detached,
          )
        : PresenceControllerState(
            userId: initialUid,
            status: _statusForLifecycle(_lifecycleState),
            appState: _appStateForLifecycle(_lifecycleState),
          );

    if (initialUid != null) {
      Future.microtask(() async {
        _startHeartbeat();
        await _writePresence();
        await _rtdb.connect(initialUid);
      });
    }

    return initialState;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    unawaited(_handleLifecycleChange(state));
  }

  Future<void> updateStatus(UserStatus status) async {
    if (!state.isAuthenticated) {
      return;
    }
    final nextAppState = status == UserStatus.offline
        ? PresenceAppState.detached
        : state.appState;
    state = state.copyWith(status: status, appState: nextAppState);
    final userId = state.userId;
    if (status == UserStatus.offline) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      if (userId != null) {
        unawaited(_rtdb.disconnect(userId));
      }
    } else {
      _startHeartbeat();
      if (userId != null) {
        unawaited(_rtdb.connect(userId));
        unawaited(_rtdb.heartbeat(userId));
      }
    }
    await _writePresence();
  }

  Future<void> setInRoom(String userId, String roomId) async {
    if (!_matchesCurrentUser(userId)) {
      return;
    }
    state = state.copyWith(inRoom: roomId);
    await _writePresence();
    unawaited(_rtdb.setInRoom(userId, roomId));
  }

  Future<void> clearInRoom(String userId) async {
    if (!_matchesCurrentUser(userId)) {
      return;
    }
    state = state.copyWith(inRoom: null);
    await _writePresence();
    unawaited(_rtdb.clearInRoom(userId));
  }

  Future<void> heartbeat() async {
    if (!state.isAuthenticated || !state.isOnline) {
      return;
    }
    await _writePresence();
    final userId = state.userId;
    if (userId != null) unawaited(_rtdb.heartbeat(userId));
  }

  Future<void> _handleAuthChange(String? previousUid, String? nextUid) async {
    final previous = previousUid?.trim();
    final next = nextUid?.trim();

    if (previous != null && previous.isNotEmpty && previous != next) {
      AppTelemetry.updateRoomState(
        roomId: null,
        joinedUserId: previous,
        inRoom: null,
        presenceStatus: UserStatus.offline.name,
        globalPresenceOnline: false,
      );
      unawaited(_rtdb.disconnect(previous));
    }

    if (next == null || next.isEmpty) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      state = const PresenceControllerState(
        status: UserStatus.offline,
        appState: PresenceAppState.detached,
      );
      return;
    }

    state = PresenceControllerState(
      userId: next,
      status: _statusForLifecycle(_lifecycleState),
      appState: _appStateForLifecycle(_lifecycleState),
      inRoom: previous == next ? state.inRoom : null,
    );
    _startHeartbeat();
    await _writePresence();
    unawaited(_rtdb.connect(next));
  }

  Future<void> _handleLifecycleChange(AppLifecycleState lifecycleState) async {
    if (!state.isAuthenticated) {
      return;
    }

    final nextStatus = _statusForLifecycle(lifecycleState);
    final nextAppState = _appStateForLifecycle(lifecycleState);
    state = state.copyWith(status: nextStatus, appState: nextAppState);

    final userId = state.userId;
    if (nextStatus == UserStatus.offline) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      if (userId != null) {
        unawaited(_rtdb.disconnect(userId));
      }
    } else {
      _startHeartbeat();
      if (userId != null) {
        unawaited(_rtdb.connect(userId));
        unawaited(_rtdb.heartbeat(userId));
      }
    }

    await _writePresence();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    if (!state.isAuthenticated || !state.isOnline) {
      return;
    }
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      unawaited(heartbeat());
    });
  }

  bool _matchesCurrentUser(String userId) {
    final currentUserId = state.userId;
    return currentUserId != null && currentUserId == userId.trim();
  }

  Future<void> _writePresence() async {
    final userId = state.userId;
    if (userId == null || userId.trim().isEmpty) {
      return;
    }
    final isOnline = state.status != UserStatus.offline;
    AppTelemetry.updateRoomState(
      roomId: state.isOnline ? state.inRoom : null,
      joinedUserId: userId,
      inRoom: state.isOnline ? state.inRoom : null,
      presenceStatus: state.status.name,
      globalPresenceOnline: isOnline,
    );
  }

  UserStatus _statusForLifecycle(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        return UserStatus.online;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return UserStatus.away;
      case AppLifecycleState.detached:
        return UserStatus.offline;
    }
  }

  PresenceAppState _appStateForLifecycle(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.resumed:
        return PresenceAppState.foreground;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        return PresenceAppState.background;
      case AppLifecycleState.detached:
        return PresenceAppState.detached;
    }
  }
}



