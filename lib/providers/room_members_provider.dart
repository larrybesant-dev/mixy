import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/room_service.dart';
import '../models/room_member_model.dart';

/// Cache RoomService as a singleton
final roomServiceProvider = Provider<RoomService>((ref) {
  return RoomService();
});

/// Stream room members via cached service
final roomMembersProvider = StreamProvider.family<List<RoomMember>, String>((ref, roomId) {
  final roomService = ref.watch(roomServiceProvider);
  return roomService.streamRoomMembers(roomId);
});
