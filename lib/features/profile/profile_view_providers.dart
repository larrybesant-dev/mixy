import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../presentation/providers/user_provider.dart';
import '../../services/presence_repository.dart';
import '../../models/user_presence.dart';
import '../../models/user_profile.dart';

class UserProfileBasePayload {
  const UserProfileBasePayload({
    required this.userSnapshot,
    required this.privacy,
  });

  final DocumentSnapshot<Map<String, dynamic>> userSnapshot;
  final Map<String, dynamic> privacy;
}

final userProfileBaseProvider = FutureProvider.autoDispose
    .family<UserProfileBasePayload, String>((ref, profileUserId) async {
      final firestore = ref.watch(firestoreProvider);
      final viewerId = ref.watch(userProvider)?.id;

      final userRef = firestore.collection('users').doc(profileUserId);
      final userSnapshot = await userRef.get();

      Map<String, dynamic> privacyData = const <String, dynamic>{};
      if (viewerId == profileUserId) {
        final privacySnapshot = await userRef
            .collection('privacy')
            .doc('settings')
            .get();
        privacyData = privacySnapshot.data() ?? const <String, dynamic>{};
      }

      return UserProfileBasePayload(
        userSnapshot: userSnapshot,
        privacy: privacyData,
      );
    });

/// A Riverpod stream provider that watches changes to a user's presence node in Firestore.
final userPresenceStreamProvider = StreamProvider.autoDispose
    .family<UserPresence, String>((ref, userId) {
      final repository = ref.watch(presenceRepositoryProvider);
      return repository.watchUserPresence(userId).map((presence) {
        return UserPresence(
          isOnline: presence.online,
          lastSeen: presence.lastSeen,
          currentRoomId: presence.roomId,
        );
      });
    });

/// A Riverpod future provider that fetches a user's profile metadata.
final userProfileFutureProvider = FutureProvider.autoDispose
    .family<UserProfile, String>((ref, userId) async {
      final firestore = ref.watch(firestoreProvider);
      final doc = await firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) {
        throw Exception('User profile not found');
      }
      return UserProfile.fromJson(doc.data()!, doc.id);
    });




