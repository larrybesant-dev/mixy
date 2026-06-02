import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../feed/providers/typing_providers.dart';
import '../../../presentation/providers/user_provider.dart';
import 'presence_provider.dart';
import 'participant_providers.dart';
import '../contracts/room_activity_contract.dart';

class RoomActivityState {
  final List<RoomPresenceModel> presence;
  final Map<String, bool> typing;
  RoomActivityState({required this.presence, required this.typing});
}

final roomActivityStateProvider =
    StreamProvider.autoDispose.family<RoomActivityState, String>((ref, roomId) {
  final currentUserId = ref.watch(userProvider)?.id.trim() ?? '';
  if (currentUserId.isNotEmpty) {
    final participantValue = ref.watch(
      currentParticipantProvider(
        CurrentParticipantParams(roomId: roomId, userId: currentUserId),
      ),
    );
    if (!participantValue.hasValue || participantValue.value == null) {
      return Stream.value(
        RoomActivityState(
          presence: const <RoomPresenceModel>[],
          typing: const <String, bool>{},
        ),
      );
    }
  }

  return Stream.multi((controller) {
    List<RoomPresenceModel>? previousPresence;
    Map<String, bool>? previousTyping;

    void publish(
      List<RoomPresenceModel> presence,
      Map<String, bool> typing,
    ) {
      if (previousPresence != null &&
          previousTyping != null &&
          !RoomActivityContract.shouldRebuild(
            previousPresence ?? const <RoomPresenceModel>[],
            presence,
            previousTyping ?? const <String, bool>{},
            typing,
          )) {
        return;
      }

      previousPresence = presence;
      previousTyping = typing;

      if (!controller.isClosed) {
        controller.add(
          RoomActivityState(presence: presence, typing: typing),
        );
      }
    }

    final presenceSubscription =
        ref.listen<AsyncValue<List<RoomPresenceModel>>>(
      roomPresenceStreamProvider(roomId),
      (_, next) {
        final List<RoomPresenceModel> presence =
            next.maybeWhen<List<RoomPresenceModel>>(
          data: (value) => value,
          orElse: () => const <RoomPresenceModel>[],
        );
        final Map<String, bool> typing =
            ref.read(typingStreamProvider(roomId)).maybeWhen<Map<String, bool>>(
                  data: (value) => value,
                  orElse: () => const <String, bool>{},
                );
        publish(presence, typing);
      },
      fireImmediately: true,
    );

    final typingSubscription = ref.listen<AsyncValue<Map<String, bool>>>(
      typingStreamProvider(roomId),
      (_, next) {
        final List<RoomPresenceModel> presence = ref
            .read(roomPresenceStreamProvider(roomId))
            .maybeWhen<List<RoomPresenceModel>>(
              data: (value) => value,
              orElse: () => const <RoomPresenceModel>[],
            );
        final Map<String, bool> typing = next.maybeWhen<Map<String, bool>>(
          data: (value) => value,
          orElse: () => const <String, bool>{},
        );
        publish(presence, typing);
      },
      fireImmediately: true,
    );

    controller.onCancel = () {
      presenceSubscription.close();
      typingSubscription.close();
    };
  });
});
