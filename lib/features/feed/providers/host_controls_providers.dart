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
      return Stream.multi((controller) {
        final subscription = ref.listen(roomDocStreamProvider(roomId), (
          _,
          next,
        ) {
          if (controller.isClosed) return;
          next.whenData((data) {
            if (data != null) {
              controller.add(RoomModel.fromJson(data, roomId));
            } else {
              controller.add(
                RoomModel(
                  id: roomId,
                  name: 'Room unavailable',
                  hostId: '',
                  isLive: false,
                ),
              );
            }
          });
        });
        controller.onCancel = subscription.close;
      });
    });

/// Alias for non-canonical consumers to avoid direct `*StreamProvider`
/// identifier references while still deriving from the canonical stream.
final roomFeedLiveProvider = feedRoomStreamProvider;




