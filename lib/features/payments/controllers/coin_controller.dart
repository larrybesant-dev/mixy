/// Coin Controller
///
/// Riverpod state management for coin balance and transactions.
/// Provides providers for membership tier, coin balance, and purchase operations.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/membership_tier.dart';
import '../models/coin_package.dart';
import 'package:mixmingle/services/payments/revenuecat_service.dart';
import '../services/membership_service.dart';

/// Provider for the membership service (singleton)
final membershipServiceProvider = Provider<MembershipService>((ref) {
  return MembershipService.instance;
});

/// Provider for RevenueCat service (singleton)
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService.instance;
});

/// Stream provider for the current membership tier
final membershipTierProvider = StreamProvider<MembershipTier>((ref) {
  final service = ref.watch(membershipServiceProvider);
  return service.membershipStream;
});

/// Stream provider for the current coin balance
final coinBalanceProvider = StreamProvider<int>((ref) {
  final service = ref.watch(membershipServiceProvider);
  return service.coinBalanceStream;
});

/// Provider for current membership tier (non-stream fallback)
final currentTierProvider = Provider<MembershipTier>((ref) {
  return ref.watch(membershipServiceProvider).currentTier;
});

/// Provider for current coin balance (non-stream fallback)
final currentCoinBalanceProvider = Provider<int>((ref) {
  return ref.watch(membershipServiceProvider).coinBalance;
});

/// Provider for store offerings
final storeOfferingsProvider = Provider<List<StoreOffering>>((ref) {
  final service = ref.watch(revenueCatServiceProvider);
  return service.offerings;
});

/// Provider for membership benefits
final membershipBenefitsProvider =
    Provider.family<List<TierBenefit>, MembershipTier>((ref, tier) {
  return tier.benefits;
});

/// Provider for VIP access check
final canJoinVipRoomsProvider = Provider<bool>((ref) {
  return ref.watch(membershipServiceProvider).canJoinVipRooms;
});

/// Provider for VIP+ access check
final canJoinVipPlusRoomsProvider = Provider<bool>((ref) {
  return ref.watch(membershipServiceProvider).canJoinVipPlusRooms;
});

/// State class for purchase operations
@immutable
class PurchaseState {
  final bool isLoading;
  final String? error;
  final bool isSuccess;
  final String? successMessage;

  const PurchaseState({
    this.isLoading = false,
    this.error,
    this.isSuccess = false,
    this.successMessage,
  });

  PurchaseState copyWith({
    bool? isLoading,
    String? error,
    bool? isSuccess,
    String? successMessage,
  }) {
    return PurchaseState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isSuccess: isSuccess ?? this.isSuccess,
      successMessage: successMessage,
    );
  }

  static const initial = PurchaseState();
  static const loading = PurchaseState(isLoading: true);
}

/// Notifier for handling purchases
class PurchaseNotifier extends Notifier<PurchaseState> {
  @override
  PurchaseState build() => PurchaseState.initial;

  /// Reset state
  void reset() {
    state = PurchaseState.initial;
  }

  /// Purchase a subscription
  Future<bool> purchaseSubscription(MembershipTier tier,
      {bool isYearly = false}) async {
    state = PurchaseState.loading;

    try {
      final revenueCat = ref.read(revenueCatServiceProvider);

      // Build product ID from tier and billing period
      final productId = isYearly
          ? (tier == MembershipTier.vipPlus
              ? RevenueCatConfig.vipPlusYearly
              : RevenueCatConfig.vipYearly)
          : (tier == MembershipTier.vipPlus
              ? RevenueCatConfig.vipPlusMonthly
              : RevenueCatConfig.vipMonthly);

      final result = await revenueCat.purchaseSubscription(productId);

      if (result.success) {
        state = PurchaseState(
          isSuccess: true,
          successMessage: 'Welcome to ${tier.displayName}! ðŸŽ‰',
        );
        debugPrint(
            'âœ… [Purchase] Subscription successful: ${tier.displayName}');
        return true;
      } else {
        state = PurchaseState(error: result.errorMessage ?? 'Purchase failed');
        debugPrint(
            'âŒ [Purchase] Subscription failed: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      state = PurchaseState(error: 'An error occurred: $e');
      debugPrint('âŒ [Purchase] Error: $e');
      return false;
    }
  }

  /// Purchase a coin package
  Future<bool> purchaseCoinPackage(CoinPackage package) async {
    state = PurchaseState.loading;

    try {
      final revenueCat = ref.read(revenueCatServiceProvider);
      final membership = ref.read(membershipServiceProvider);

      // Log analytics
      await membership.logCoinPurchaseStarted(package);

      final result = await revenueCat.purchaseCoins(package);

      if (result.success) {
        // Calculate total coins including bonus
        final isVipPlus = membership.currentTier == MembershipTier.vipPlus;
        final totalCoins = package.getTotalCoins(isVipPlus);

        // Add coins to balance
        await membership.addCoins(totalCoins,
            description: 'Purchased ${package.displayName}');

        // Log success
        await membership.logCoinPurchaseCompleted(package, totalCoins);

        state = PurchaseState(
          isSuccess: true,
          successMessage: 'You received $totalCoins coins! ðŸª™',
        );
        debugPrint('âœ… [Purchase] Coins purchased: $totalCoins');
        return true;
      } else {
        await membership.logCoinPurchaseFailed(
            package, result.errorMessage ?? 'Unknown');
        state = PurchaseState(error: result.errorMessage ?? 'Purchase failed');
        debugPrint(
            'âŒ [Purchase] Coin purchase failed: ${result.errorMessage}');
        return false;
      }
    } catch (e) {
      state = PurchaseState(error: 'An error occurred: $e');
      debugPrint('âŒ [Purchase] Error: $e');
      return false;
    }
  }

  /// Restore purchases
  Future<bool> restorePurchases() async {
    state = PurchaseState.loading;

    try {
      final revenueCat = ref.read(revenueCatServiceProvider);
      final result = await revenueCat.restorePurchases();

      if (result.success) {
        state = const PurchaseState(
          isSuccess: true,
          successMessage: 'Purchases restored successfully! âœ“',
        );
        return true;
      } else {
        state = PurchaseState(error: result.errorMessage ?? 'Restore failed');
        return false;
      }
    } catch (e) {
      state = PurchaseState(error: 'An error occurred: $e');
      return false;
    }
  }
}

/// Provider for purchase operations
final purchaseProvider = NotifierProvider<PurchaseNotifier, PurchaseState>(() {
  return PurchaseNotifier();
});

/// State for coin store
@immutable
class CoinStoreState {
  final CoinPackage? selectedPackage;
  final bool showBonusInfo;

  const CoinStoreState({
    this.selectedPackage,
    this.showBonusInfo = false,
  });

  CoinStoreState copyWith({
    CoinPackage? selectedPackage,
    bool? showBonusInfo,
  }) {
    return CoinStoreState(
      selectedPackage: selectedPackage ?? this.selectedPackage,
      showBonusInfo: showBonusInfo ?? this.showBonusInfo,
    );
  }
}

/// Notifier for coin store
class CoinStoreNotifier extends Notifier<CoinStoreState> {
  @override
  CoinStoreState build() => const CoinStoreState();

  void selectPackage(CoinPackage package) {
    state = state.copyWith(selectedPackage: package);
  }

  void clearSelection() {
    state = const CoinStoreState();
  }

  void toggleBonusInfo() {
    state = state.copyWith(showBonusInfo: !state.showBonusInfo);
  }
}

/// Provider for coin store state
final coinStoreProvider =
    NotifierProvider<CoinStoreNotifier, CoinStoreState>(() {
  return CoinStoreNotifier();
});

/// Provider for available coin packages
final coinPackagesProvider = Provider<List<CoinPackage>>((ref) {
  return CoinPackage.allPackages;
});

/// Provider for checking affordability
final canAffordProvider = Provider.family<bool, int>((ref, amount) {
  return ref.watch(membershipServiceProvider).canAfford(amount);
});

/// Provider for transaction history
final coinTransactionHistoryProvider =
    FutureProvider<List<CoinTransaction>>((ref) async {
  final service = ref.watch(membershipServiceProvider);
  return service.getCoinTransactionHistory();
});

/// Extension methods for coin operations in widgets
extension CoinOperationsRef on WidgetRef {
  /// Check if user can afford an amount
  bool canAfford(int amount) =>
      read(membershipServiceProvider).canAfford(amount);

  /// Deduct coins for a gift
  Future<bool> sendGift(int amount, String recipientId) async {
    final service = read(membershipServiceProvider);
    return service.deductCoins(
      amount,
      CoinTransactionType.giftSent,
      description: 'Gift sent to user',
    );
  }

  /// Deduct coins for spotlight
  Future<bool> activateSpotlight(int amount) async {
    final service = read(membershipServiceProvider);
    return service.deductCoins(
      amount,
      CoinTransactionType.spotlight,
      description: 'Spotlight activated',
    );
  }

  /// Get current membership tier
  MembershipTier get currentTier => read(membershipServiceProvider).currentTier;

  /// Get current coin balance
  int get coinBalance => read(membershipServiceProvider).coinBalance;
}
