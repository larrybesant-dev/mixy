import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/providers/firebase_providers.dart';
import '../../features/auth/providers/admin_provider.dart';
import '../../models/wallet_model.dart';

/// Coin balance returned to admin accounts — effectively unlimited.
const _kAdminCoinBalance = 999999999;

final walletAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final walletUserIdProvider = Provider<String?>((ref) {
  return ref.watch(walletAuthProvider).currentUser?.uid;
});

final walletDetailsProvider = StreamProvider<WalletModel>((ref) {
  final userId = ref.watch(walletUserIdProvider);
  if (userId == null || userId.isEmpty) {
    return Stream<WalletModel>.value(
      const WalletModel(userId: '', coinBalance: 0),
    );
  }

  // Admin accounts are treated as having unlimited balance.
  final isAdmin = ref.watch(isAdminProvider).valueOrNull ?? false;
  if (isAdmin) {
    return Stream<WalletModel>.value(
      WalletModel(userId: userId, coinBalance: _kAdminCoinBalance),
    );
  }

  return ref.watch(walletModelStreamProvider(userId).stream);
});

final walletProvider = StreamProvider<double>((ref) {
  return ref
      .watch(walletDetailsProvider)
      .when(
        data: (wallet) => Stream<double>.value(wallet.coinBalance.toDouble()),
        loading: () => const Stream<double>.empty(),
        error: (__, _) => const Stream<double>.empty(),
      );
});




