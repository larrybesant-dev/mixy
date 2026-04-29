import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
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

final roomActivityStateProvider = StreamProvider.autoDispose.family<RoomActivityState, String>((ref, roomId) async* {
  final currentUserId = ref.watch(userProvider)?.id.trim() ?? '';
  if (currentUserId.isNotEmpty) {
    final participantValue = ref.watch(
      currentParticipantProvider(
        CurrentParticipantParams(roomId: roomId, userId: currentUserId),
      ),
    );
    if (!participantValue.hasValue || participantValue.value == null) {
      yield RoomActivityState(presence: const <RoomPresenceModel>[], typing: const <String, bool>{});
      return;
    }
  }

  List<RoomPresenceModel>? previousPresence;
  Map<String, bool>? previousTyping;
  // ignore: deprecated_member_use
  final presenceStream = ref.watch(roomPresenceStreamProvider(roomId).stream);
  // ignore: deprecated_member_use
  final typingStream = ref.watch(typingStreamProvider(roomId).stream);
  await for (final values in Rx.combineLatest2(
    presenceStream,
    typingStream,
    (presence, typing) => [presence, typing],
  )) {
    final presence = values[0] as List<RoomPresenceModel>;
    final typing = values[1] as Map<String, bool>;
    if (previousPresence != null && previousTyping != null &&
        !RoomActivityContract.shouldRebuild(previousPresence, presence, previousTyping, typing)) {
      continue;
    }
    previousPresence = presence;
    previousTyping = typing;
    yield RoomActivityState(presence: presence, typing: typing);
  }
});
