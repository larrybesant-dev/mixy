import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/rtc_room_service.dart';

/// Holds the live [RtcRoomService] instance for a room session.
///
/// Written by [LiveRoomScreen] after the RTC channel connects.
/// Auto-disposed when the room UI goes away so stale services do not leak
/// across sessions.
/// Keyed by roomId so concurrent rooms (future feature) stay isolated.
final rtcServiceProvider = StateProvider.autoDispose
    .family<RtcRoomService?, String>((ref, roomId) => null);

/// Exposes the list of active remote speaker UIDs in a room.
///
/// Refreshes automatically whenever speaking activity changes (via [RtcRoomService.onSpeakerActivityChanged]).
final activeSpeakersProvider = StateNotifierProvider.autoDispose
    .family<ActiveSpeakersNotifier, List<int>, String>((ref, roomId) {
  final rtcService = ref.watch(rtcServiceProvider(roomId));
  return ActiveSpeakersNotifier(rtcService);
});

class ActiveSpeakersNotifier extends StateNotifier<List<int>> {
  ActiveSpeakersNotifier(this._rtcService) : super([]) {
    _init();
  }

  final RtcRoomService? _rtcService;

  void _init() {
    final service = _rtcService;
    if (service == null) return;

    // Initial load of speakers
    _updateSpeakers();

    // Listen to changes in speaker activity
    service.onSpeakerActivityChanged = _updateSpeakers;
  }

  void _updateSpeakers() {
    final service = _rtcService;
    if (service == null) {
      state = [];
      return;
    }

    final List<int> speaking = [];
    for (final uid in service.remoteUids) {
      if (service.isRemoteSpeaking(uid)) {
        speaking.add(uid);
      }
    }

    state = speaking;
  }
}

/// Exposes whether a specific remote user is currently speaking.
final isRemoteSpeakingProvider = Provider.autoDispose
    .family<bool, ({String roomId, int uid})>((ref, arg) {
  final activeSpeakers = ref.watch(activeSpeakersProvider(arg.roomId));
  return activeSpeakers.contains(arg.uid);
});

/// Exposes whether the active WebRTC connection is currently degraded.
final isNetworkDegradedProvider = StateNotifierProvider.autoDispose
    .family<NetworkQualityNotifier, bool, String>((ref, roomId) {
  final rtcService = ref.watch(rtcServiceProvider(roomId));
  return NetworkQualityNotifier(rtcService);
});

class NetworkQualityNotifier extends StateNotifier<bool> {
  NetworkQualityNotifier(this._rtcService) : super(false) {
    _init();
  }

  final RtcRoomService? _rtcService;

  void _init() {
    final service = _rtcService;
    if (service == null) return;

    state = service.isNetworkDegraded;

    service.onNetworkQualityChanged = () {
      state = service.isNetworkDegraded;
    };
  }
}
