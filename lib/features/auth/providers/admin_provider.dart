import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../controllers/auth_controller.dart';

/// Streams the existence of a document in `roles/admins/{uid}`.
/// This is the enterprise-safe source of truth for admin status.
final isAdminProvider = StreamProvider<bool>((ref) {
  final uid = ref.watch(authControllerProvider).uid;
  if (uid == null || uid.isEmpty) {
    return Stream.value(false);
  }

  return ref
      .watch(firestoreProvider)
      .collection('roles')
      .doc('admins')
      .collection('members')
      .doc(
        uid,
      ) // Single-document read — .limit(1) not applicable for document snapshots.
      .snapshots()
      .map((doc) => doc.exists);
});




