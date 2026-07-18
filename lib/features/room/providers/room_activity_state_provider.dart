import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../feed/providers/typing_providers.dart';
import '../../../presentation/providers/user_provider.dart';
import 'presence_provider.dart';
import 'participant_providers.dart';

class RoomActivityState {
  final List<RoomPresenceModel> presence;
  final Map<String, bool> typing;
  const RoomActivityState({required this.presence, required this.typing});
}

final roomActivityStateProvider = Provider.autoDispose
    .family<AsyncValue<RoomActivityState>, String>((ref, roomId) {
      final currentUserId = ref.watch(userProvider)?.id.trim() ?? '';
      if (currentUserId.isNotEmpty) {
        final participantValue = ref.watch(
          currentParticipantProvider(
            CurrentParticipantParams(roomId: roomId, userId: currentUserId),
          ),
        );
        if (!participantValue.hasValue || participantValue.value == null) {
          return const AsyncValue.data(
            RoomActivityState(
              presence: <RoomPresenceModel>[],
              typing: <String, bool>{},
            ),
          );
        }
      }

      final presenceAsync = ref.watch(roomPresenceLiveProvider(roomId));
      final typingAsync = ref.watch(roomTypingLiveProvider(roomId));

      if (presenceAsync.hasError) {
        return AsyncValue<RoomActivityState>.error(
          presenceAsync.error!,
          presenceAsync.stackTrace ?? StackTrace.empty,
        );
      }
      if (typingAsync.hasError) {
        return AsyncValue<RoomActivityState>.error(
          typingAsync.error!,
          typingAsync.stackTrace ?? StackTrace.empty,
        );
      }

      if (!presenceAsync.hasValue || !typingAsync.hasValue) {
        return const AsyncValue<RoomActivityState>.loading();
      }

      final presence = presenceAsync.value ?? const <RoomPresenceModel>[];
      final typing = typingAsync.value ?? const <String, bool>{};

      return AsyncValue<RoomActivityState>.data(
        RoomActivityState(presence: presence, typing: typing),
      );
    });




