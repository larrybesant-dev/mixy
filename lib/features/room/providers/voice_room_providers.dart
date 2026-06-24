import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixmingle/shared/models/room_role.dart';

/// Provider for voice room chat messages - manages local state for each room
/// Use as: ref.watch(voiceRoomChatProvider(roomId)).messages
// Deprecated: Use chatMessagesProvider from room_subcollection_providers instead
// This provider uses the legacy VoiceRoomChatMessage model
// TODO: Remove after migration to unified ChatMessage model

/// Notifier for managing chat messages in a voice room with change notifications
// Deprecated: VoiceRoomChatNotifier - use ChatMessage-based providers instead
/*
class VoiceRoomChatNotifier extends StateNotifier<List<VoiceRoomChatMessage>> {
  VoiceRoomChatNotifier() : super([]);

  /// Add a regular message
  void addMessage({
    required String userId,
    required String displayName,
    required String message,
  }) {
    // Ensure displayName is never empty
    final finalDisplayName = displayName.isNotEmpty ? displayName : 'User';

    final newMessage = VoiceRoomChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      displayName: finalDisplayName,
      message: message,
      timestamp: DateTime.now(),
      type: MessageType.text,
    );

    state = [...state, newMessage];
  }

  /// Add a system message
  void addSystemMessage(String message) {
    final systemMessage = VoiceRoomChatMessage.system(
      message: message,
      timestamp: DateTime.now(),
    );

    state = [...state, systemMessage];
  }
}
*/

/// Provider for room roles/participants - returns empty map for each room
/// In voice_room_page.dart, participants are managed with local state
final roomRolesProvider = Provider.autoDispose
    .family<Map<String, RoomParticipant>, String>((ref, roomId) {
  return {};
});
