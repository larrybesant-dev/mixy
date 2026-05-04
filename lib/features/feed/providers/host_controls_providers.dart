import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../repository/host_controls_repository.dart';
import '../../../models/room_model.dart';
import '../../room/providers/participant_providers.dart';

final hostControlsRepositoryProvider = Provider<HostControlsRepository>((ref) {
  return HostControlsRepository(ref.watch(firestoreProvider));
});

/// Derives a [RoomModel] view of the room document from the canonical
/// [roomDocStreamProvider]. No new Firestore subscription is opened here —
/// this is a pure transformation of the already-active stream.
final feedRoomStreamProvider = StreamProvider.autoDispose
    .family<RoomModel, String>((ref, roomId) {
      return ref.watch(roomDocStreamProvider(roomId).stream).map((data) {
        if (data != null) {
          return RoomModel.fromJson(data, roomId);
        }
        return RoomModel(
          id: roomId,
          name: 'Room unavailable',
          hostId: '',
          isLive: false,
        );
      });
    });
