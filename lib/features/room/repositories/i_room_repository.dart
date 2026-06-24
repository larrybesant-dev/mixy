// lib/features/room/repositories/i_room_repository.dart
//
// Abstract contract for voice/video room operations.
import 'package:mixvy/shared/models/room.dart';

abstract class IRoomRepository {
  /// Get a room by its ID, or null if not found.
  Future<Room?> getRoom(String roomId);

  /// Watch a room document for real-time updates.
  Stream<Room?> watchRoom(String roomId);

  /// List publicly visible live rooms.
  Stream<List<Room>> watchLiveRooms({int limit = 50});

  /// Create a new room document. Returns the generated room ID.
  /// UID validation is performed inside the implementation.
  Future<String> createRoom({
    required String hostUid,
    required Map<String, dynamic> roomData,
  });

  /// Update selected fields on a room.
  Future<void> updateRoom({
    required String roomId,
    required String requestingUid,
    required Map<String, dynamic> fields,
  });

  /// Soft-delete / close a room (sets status = closed).
  Future<void> closeRoom({
    required String roomId,
    required String requestingUid,
  });

  /// Add a participant record to the room's sub-collection.
  Future<void> joinRoom({
    required String roomId,
    required String uid,
    required Map<String, dynamic> participantData,
  });

  /// Remove a participant from the room's sub-collection.
  Future<void> leaveRoom({required String roomId, required String uid});
}

