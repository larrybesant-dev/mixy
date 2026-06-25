import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/room_service.dart';
import '../models/room_model.dart';

/// Cache RoomService as a singleton
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

/// Stream all rooms via cached service
final roomListProvider = StreamProvider<List<Room>>((ref) {
  final roomService = ref.watch(roomServiceProvider);
  return roomService.streamRooms();
});
