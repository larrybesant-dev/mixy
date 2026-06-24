import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/user_providers.dart';
import '../providers/service_providers.dart';

final unreadCountProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    return const Stream.empty();
  }

  final messaging = ref.watch(messagingServiceProvider);

  return messaging.streamConversations(currentUser.id).map((convos) {
    int total = 0;
    for (final chatRoom in convos) {
      final unread = (chatRoom.unreadCounts[currentUser.id] ?? 0);
      total += unread;
    }
    return total;
  });
});
