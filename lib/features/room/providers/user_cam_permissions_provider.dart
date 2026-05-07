import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'room_firestore_provider.dart';

class UserCamPermissionsController {
  UserCamPermissionsController(this._db);

  final FirebaseFirestore _db;

  Future<void> setAllowedViewers({
    required String userId,
    required List<String> allowedViewers,
  }) async {
    await _db.collection('userCamPermissions').doc(userId).set({
      'allowedViewers': allowedViewers,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Atomically appends [viewerId] to [userId]'s allowedViewers list.
  Future<void> addAllowedViewer({
    required String userId,
    required String viewerId,
  }) async {
    await _db.collection('userCamPermissions').doc(userId).set({
      'allowedViewers': FieldValue.arrayUnion([viewerId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Atomically removes [viewerId] from [userId]'s allowedViewers list.
  Future<void> removeAllowedViewer({
    required String userId,
    required String viewerId,
  }) async {
    await _db.collection('userCamPermissions').doc(userId).set({
      'allowedViewers': FieldValue.arrayRemove([viewerId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

final userCamPermissionsControllerProvider =
    Provider<UserCamPermissionsController>((ref) {
      return UserCamPermissionsController(ref.watch(roomFirestoreProvider));
    });

final userCamAllowedViewersProvider = StreamProvider.autoDispose
    .family<List<String>, String>((ref, userId) {
      final firestore = ref.watch(roomFirestoreProvider);
      return firestore
          .collection('userCamPermissions')
          .doc(
            userId,
          ) // Single-document read — .limit(1) not applicable for document snapshots.
          .snapshots()
          .map((doc) {
            final data = doc.data();
            if (data == null) {
              return const <String>[];
            }
            final raw = data['allowedViewers'];
            if (raw is! List) {
              return const <String>[];
            }
            return raw
                .whereType<String>()
                .map((value) => value.trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false);
          });
    });
