import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../repository/typing_repository.dart';

final typingRepositoryProvider = Provider<TypingRepository>((ref) {
  return TypingRepository(ref.watch(firestoreProvider));
});

final typingStreamProvider =
    StreamProvider.autoDispose.family<Map<String, bool>, String>((ref, roomId) {
  return ref.read(typingRepositoryProvider).typingStream(roomId);
});

/// Derived provider: typing user IDs (those with isTyping = true)
final typingUserIdsProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, roomId) {
  return Stream.multi((controller) {
    final subscription = ref.listen(typingStreamProvider(roomId), (
      _,
      next,
    ) {
      if (controller.isClosed) return;
      next.whenData((typingMap) {
        controller.add(
          typingMap.entries
              .where((entry) => entry.value == true)
              .map((entry) => entry.key)
              .toList(growable: false),
        );
      });
    });
    controller.onCancel = subscription.close;
  });
});
