import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/firebase_providers.dart';
import '../../features/auth/providers/admin_provider.dart';
import '../../models/wallet_model.dart';

/// Coin balance returned to admin accounts — effectively unlimited.
const _kAdminCoinBalance = 999999999;

final walletAuthProvider = Provider<FirebaseAuth>((ref) {
  return FirebaseAuth.instance;
});

final walletFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return ref.watch(firestoreProvider);
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

  final firestore = ref.watch(walletFirestoreProvider);
  // Single-document read — .limit(1) not applicable for document snapshots.
  final docStream = firestore.collection('wallets').doc(userId).snapshots();

  return docStream.asyncMap((walletDoc) async {
    final walletData = walletDoc.data();

    // If wallet doc exists, use it as primary truth.
    if (walletData != null) {
      return WalletModel.fromJson({'userId': userId, ...walletData});
    }

    // Fallback to legacy balance in users doc if wallet doesn't exist yet
    final userDoc = await firestore.collection('users').doc(userId).get();
    final userData = userDoc.data();

    if (userData == null) {
      return WalletModel(userId: userId);
    }

    return WalletModel(
      userId: userId,
      coinBalance:
          ((userData['balance'] ?? userData['coinBalance']) as num?)?.toInt() ??
          0,
    );
  });
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




