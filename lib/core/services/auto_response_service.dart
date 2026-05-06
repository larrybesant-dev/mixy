import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:state_notifier/state_notifier.dart';

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
      final controller = AutoResponseController();
      controller.initialize();
      return controller;
    });

class AutoResponseController extends StateNotifier<AutoResponseState> {
  AutoResponseController() : super(const AutoResponseState());

  bool _initialized = false;

  void initialize() {
    if (_initialized) {
      return;
    }
    _initialized = true;
  }
}
