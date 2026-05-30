import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/referral_model.dart';
import '../../services/referral_service.dart';
import 'wallet_provider.dart';

final referralServiceProvider = Provider<ReferralService>((ref) {
  final firestore = ref.watch(walletFirestoreProvider);
  return ReferralService(firestore: firestore);
});

final referralCodeProvider = StreamProvider<String?>((ref) {
  final userId = ref.watch(walletUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream<String?>.value(null);
  }

  return ref.watch(referralServiceProvider).referralCodeStream(userId);
});

final referralEarningsProvider = StreamProvider<double>((ref) {
  final userId = ref.watch(walletUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream<double>.value(0);
  }

  return ref.watch(referralServiceProvider).referralEarningsTotalStream(userId);
});

final referralAttributionsProvider =
    StreamProvider<List<ReferralAttributionModel>>((ref) {
      final userId = ref.watch(walletUserIdProvider);
      if (userId == null || userId.isEmpty) {
        return Stream<List<ReferralAttributionModel>>.value(
          <ReferralAttributionModel>[],
        );
      }

      return ref.watch(referralServiceProvider).referralsForUserStream(userId);
    });




