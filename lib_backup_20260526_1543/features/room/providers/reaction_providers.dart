import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repository/room_repository.dart';
import '../../../presentation/providers/user_provider.dart';

final roomReactionsStreamProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>((ref, roomId) {
  final repo = ref.watch(roomRepositoryProvider);
  return repo.watchRoomReactions(roomId);
});

final sendRoomReactionProvider = Provider.autoDispose
    .family<Future<void> Function(String emoji), String>((ref, roomId) {
  return (String emoji) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final repo = ref.read(roomRepositoryProvider);
    await repo.sendRoomReaction(
      roomId: roomId,
      userId: user.id,
      emoji: emoji,
    );
  };
});
