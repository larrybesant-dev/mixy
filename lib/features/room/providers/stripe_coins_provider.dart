import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/coin_package.dart';
import 'stripe_coins_controller.dart';

/// Provides the Stripe coins controller.
final stripeCoinsControllerProvider = Provider((ref) {
  return StripeCoinsController();
});

/// Provides the list of available coin packages for purchase.
final coinPackagesProvider = Provider((ref) {
  return CoinCatalog.packages;
});

/// State for coin purchase operation.
class CoinPurchaseState {
  final bool isLoading;
  final String? error;
  final bool success;

  const CoinPurchaseState({
    this.isLoading = false,
    this.error,
    this.success = false,
  });

  CoinPurchaseState copyWith({
    bool? isLoading,
    String? error,
    bool? success,
  }) {
    return CoinPurchaseState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      success: success ?? this.success,
    );
  }
}

/// State notifier for managing coin purchase flow.
class CoinPurchaseNotifier extends StateNotifier<CoinPurchaseState> {
  final StripeCoinsController _controller;

  CoinPurchaseNotifier(this._controller) : super(const CoinPurchaseState());

  Future<void> purchaseCoins(CoinPackage package) async {
    state = state.copyWith(isLoading: true, error: null, success: false);
    try {
      await _controller.purchaseCoinPackage(package: package);
      state = state.copyWith(isLoading: false, success: true);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
        success: false,
      );
      rethrow;
    }
  }
}

/// Provides state management for coin purchases.
final coinPurchaseProvider =
    StateNotifierProvider<CoinPurchaseNotifier, CoinPurchaseState>((ref) {
  final controller = ref.watch(stripeCoinsControllerProvider);
  return CoinPurchaseNotifier(controller);
});
