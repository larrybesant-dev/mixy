import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/wallet_service.dart';
import '../models/user_wallet_model.dart';

/// Cache WalletService as a singleton
final walletServiceProvider = Provider<WalletService>((ref) {
  return WalletService();
});

/// Stream user wallet via cached service
final walletProvider = StreamProvider.family<UserWallet?, String>((ref, userId) {
  final walletService = ref.watch(walletServiceProvider);
  return walletService.streamWallet(userId);
});
