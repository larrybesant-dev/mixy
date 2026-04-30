import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../presentation/providers/user_provider.dart';

class UserProfileBasePayload {
  const UserProfileBasePayload({
    required this.userSnapshot,
    required this.privacy,
  });

  final DocumentSnapshot<Map<String, dynamic>> userSnapshot;
  final Map<String, dynamic> privacy;
}

final userProfileBaseProvider =
    FutureProvider.autoDispose.family<UserProfileBasePayload, String>((
  ref,
  profileUserId,
) async {
  final firestore = ref.watch(firestoreProvider);
  final viewerId = ref.watch(userProvider)?.id;

  final userRef = firestore.collection('users').doc(profileUserId);
  final userSnapshot = await userRef.get();

  Map<String, dynamic> privacyData = const <String, dynamic>{};
  if (viewerId == profileUserId) {
    final privacySnapshot = await userRef.collection('privacy').doc('settings').get();
    privacyData = privacySnapshot.data() ?? const <String, dynamic>{};
  }

  return UserProfileBasePayload(userSnapshot: userSnapshot, privacy: privacyData);
});
