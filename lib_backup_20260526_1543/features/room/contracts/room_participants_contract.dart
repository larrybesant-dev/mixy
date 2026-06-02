import 'package:mixvy/models/room_participant_model.dart';

class RoomParticipantsContract {
  /// Returns true when the UI should rebuild.
  ///
  /// Checks both membership (join/leave) and visible state changes (mic, cam,
  /// role) so the on-mic panel and participant count stay accurate when users
  /// go on/off mic without joining or leaving the room.
  static bool shouldRebuild(
    List<RoomParticipantModel> oldList,
    List<RoomParticipantModel> newList,
  ) {
    if (oldList.length != newList.length) return true;
    final oldMap = <String, RoomParticipantModel>{
      for (final p in oldList) p.userId: p,
    };
    for (final p in newList) {
      final old = oldMap[p.userId];
      if (old == null) return true; // new member joined
      if (old.role != p.role || old.micOn != p.micOn || old.camOn != p.camOn) {
        return true; // visible state changed
      }
    }
    return false;
  }
}
