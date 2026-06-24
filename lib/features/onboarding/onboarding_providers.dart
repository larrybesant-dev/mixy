import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import '../../core/utils/app_logger.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Step index  (0 = Welcome, 1 = Permissions, 2 = AgeVerification,
//              3 = Interests, 4 = Tutorial / All-Done)
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingStepNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next() => state++;
  void goTo(int step) => state = step;
  void reset() => state = 0;
}

final onboardingStepProvider =
    NotifierProvider<OnboardingStepNotifier, int>(() {
  return OnboardingStepNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// Whether the current authenticated user has completed onboarding.
// Reads directly from Firestore snapshot so it reacts in real-time.
// ─────────────────────────────────────────────────────────────────────────────
final onboardingCompletionProvider = StreamProvider.autoDispose<bool>((ref) {
  final uid = fb_auth.FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(true);
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((doc) => doc.data()?['onboardingComplete'] as bool? ?? false);
});

// ─────────────────────────────────────────────────────────────────────────────
// In-session age-verification state (ephemeral — reset on app restart)
// ─────────────────────────────────────────────────────────────────────────────
class _AgeVerificationNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

final ageVerificationProvider =
    NotifierProvider<_AgeVerificationNotifier, bool>(() {
  return _AgeVerificationNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// Local onboarding completion flag (session-scoped).
// Used to bypass the Firestore check when Firestore write fails/is delayed.
// ─────────────────────────────────────────────────────────────────────────────
class _LocalOnboardingCompletionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void complete() => state = true;
}

final localOnboardingCompletionProvider =
    NotifierProvider<_LocalOnboardingCompletionNotifier, bool>(() {
  return _LocalOnboardingCompletionNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// In-session selected interests (for step 3 quick-pick)
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingInterestsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];

  void toggle(String interest) {
    if (state.contains(interest)) {
      state = [...state]..remove(interest);
    } else {
      state = [...state, interest];
    }
  }

  void setAll(List<String> interests) => state = List.from(interests);
}

final onboardingInterestsProvider =
    NotifierProvider<OnboardingInterestsNotifier, List<String>>(() {
  return OnboardingInterestsNotifier();
});

// ─────────────────────────────────────────────────────────────────────────────
// Onboarding-save action provider
// ─────────────────────────────────────────────────────────────────────────────
final onboardingSaveProvider =
    Provider<Future<void> Function(OnboardingPayload)>((ref) {
  return (payload) async {
    final userId = payload.userId;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update(<String, dynamic>{
        'onboardingComplete': true,
        'is18PlusVerified': payload.ageVerified,
        if (payload.interests.isNotEmpty) 'interests': payload.interests,
        if (payload.birthday != null)
          'birthday': Timestamp.fromDate(payload.birthday!),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      AppLogger.info('[OnboardingProviders] onboarding saved for $userId');
    } catch (e, st) {
      AppLogger.error('[OnboardingProviders] save failed', e, st);
      rethrow;
    }
  };
});

class OnboardingPayload {
  final String userId;
  final bool ageVerified;
  final List<String> interests;
  final DateTime? birthday;

  const OnboardingPayload({
    required this.userId,
    required this.ageVerified,
    required this.interests,
    this.birthday,
  });
}
