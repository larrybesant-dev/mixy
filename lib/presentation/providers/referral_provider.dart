import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../models/referral_model.dart';
import '../../services/referral_service.dart';
import 'wallet_provider.dart';

final referralServiceProvider = Provider<ReferralService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return ReferralService(firestore: firestore);
});

final referralCodeProvider = Provider<AsyncValue<String?>>((ref) {
  final userId = ref.watch(walletUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return const AsyncValue.data(null);
  }

  return ref.watch(referralCodeForUserProvider(userId));
});

final referralEarningsProvider = Provider<AsyncValue<double>>((ref) {
  final userId = ref.watch(walletUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return const AsyncValue.data(0);
  }

  return ref.watch(referralEarningsForUserProvider(userId));
});

final referralAttributionsProvider =
    Provider<AsyncValue<List<ReferralAttributionModel>>>((ref) {
      final userId = ref.watch(walletUserIdProvider);
      if (userId == null || userId.isEmpty) {
        return const AsyncValue.data(<ReferralAttributionModel>[]);
      }

      return ref.watch(referralAttributionsForUserProvider(userId));
    });




