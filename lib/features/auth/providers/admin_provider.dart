import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import '../controllers/auth_controller.dart';

/// Streams the `admin` boolean field from the current user's Firestore doc.
/// Returns `false` when there is no signed-in user or the field is absent.
final isAdminProvider = Provider<AsyncValue<bool>>((ref) {
  final uid = ref.watch(authControllerProvider).uid;
  if (uid == null || uid.isEmpty) {
    return const AsyncData(false);
  }

  return ref.watch(userDataStreamProvider(uid)).whenData((data) {
    if (data == null) return false;
    final raw = data['admin'];
    if (raw is bool) return raw;
    if (raw is int) return raw != 0;
    return false;
  });
});
