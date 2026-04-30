import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../repository/host_controls_repository.dart';
import '../../../models/room_model.dart';
import '../../../services/room_service.dart';

final hostControlsRepositoryProvider = Provider<HostControlsRepository>((ref) {
  return HostControlsRepository(ref.watch(firestoreProvider));
});

final feedRoomStreamProvider = StreamProvider.family<RoomModel, String>((ref, roomId) {
  return ref.read(roomServiceProvider).watchRoomById(roomId).map((room) {
    if (room != null) {
      return room;
    }
    return RoomModel(
      id: roomId,
      name: 'Room unavailable',
      hostId: '',
      isLive: false,
    );
  });
});
