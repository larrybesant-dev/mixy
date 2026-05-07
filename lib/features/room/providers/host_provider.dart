import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_firestore_provider.dart';

String? _asNullableString(dynamic value) {
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
  return null;
}

class Host {
  final String userId;

  Host(this.userId);
}

final hostProvider = StreamProvider.autoDispose.family<Host?, String>((
  ref,
  roomId,
) {
  final firestore = ref.watch(roomFirestoreProvider);
  return firestore
      .collection('rooms')
      .doc(
        roomId,
      ) // Single-document read — .limit(1) not applicable for document snapshots.
      .snapshots()
      .map((doc) {
        final data = doc.data();
        final hostId = _asNullableString(data?['hostId']);
        if (hostId == null || hostId.isEmpty) {
          return null;
        }
        return Host(hostId);
      });
});
