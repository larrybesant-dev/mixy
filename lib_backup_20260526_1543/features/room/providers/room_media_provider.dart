import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../media/room_media_controller.dart';
import '../media/stream_control.dart';

/// One [RoomMediaController] per room, scoped to the room lifecycle.
///
/// Starts the rebalance+enforcement timer on creation and stops it on autoDispose.
/// The [StreamControl] is created here so it shares the same [Ref] for
/// resolving [rtcServiceProvider] and [liveRoomMediaControllerProvider].
final roomMediaControllerProvider =
    Provider.autoDispose.family<RoomMediaController, String>((ref, roomId) {
  final streamControl = StreamControl(roomId: roomId, ref: ref);
  final controller = RoomMediaController(streamControl: streamControl);
  controller.start();
  ref.onDispose(controller.stop);
  return controller;
});
