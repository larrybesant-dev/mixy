import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_providers.dart';

final profileCompletionProvider = Provider<bool>((ref) {
  final currentUserProfile = ref.watch(currentUserProfileProvider).value;

  if (currentUserProfile == null) return false;

  // Only require a displayName to be considered complete.
  // Age, gender, and interests are optional — users can fill them in later.
  final hasDisplayName = currentUserProfile.displayName != null &&
      currentUserProfile.displayName!.isNotEmpty;

  return hasDisplayName;
});

final needsOnboardingProvider = Provider<bool>((ref) {
  // Always return false — onboarding redirect is disabled.
  // Remove this override to re-enable the onboarding gate.
  return false;
});

/// Calculates profile completeness score (0-100) for a given user
final profileCompletenessScoreProvider =
    FutureProvider.family<double, String>((ref, userId) async {
  try {
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(userId).get();

    if (!userDoc.exists) return 0.0;

    final data = userDoc.data() ?? {};
    double score = 0.0;

    // Basic fields (25 points each)
    if ((data['displayName'] as String?)?.isNotEmpty ?? false) score += 25;
    if ((data['photoUrl'] as String?)?.isNotEmpty ?? false) score += 25;
    if ((data['bio'] as String?)?.isNotEmpty ?? false) score += 25;
    if ((data['age'] as int?) != null && (data['age'] as int) > 0) score += 25;

    return score.clamp(0.0, 100.0);
  } catch (e) {
    return 0.0;
  }
});
