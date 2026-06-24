/// RevenueCat Service - Stub for compilation
/// TODO: Implement full RevenueCat integration
library;

import '../../features/payments/models/membership_tier.dart';
import '../../features/payments/models/coin_package.dart';

/// Result returned by purchase operations
class PurchaseResult {
  final bool success;
  final String? errorMessage;
  const PurchaseResult({required this.success, this.errorMessage});
}

/// Store offering stub
class StoreOffering {
  final String identifier;
  final String title;
  final String description;
  const StoreOffering({
    required this.identifier,
    required this.title,
    required this.description,
  });
}

/// RevenueCat product ID constants
class RevenueCatConfig {
  static const String vipMonthly = 'vip_monthly';
  static const String vipYearly = 'vip_yearly';
  static const String vipPlusMonthly = 'vip_plus_monthly';
  static const String vipPlusYearly = 'vip_plus_yearly';
}

class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  /// Singleton accessor
  static RevenueCatService get instance => _instance;

  /// Available store offerings (stub)
  List<StoreOffering> get offerings => const [];

  /// Initialize RevenueCat SDK
  Future<void> init() async {
    // TODO: Initialize RevenueCat with API key
  }

  /// Purchase a membership tier
  Future<PurchaseResult> purchaseMembership(MembershipTier tier) async {
    // DEV STUB - monetization disabled
    // TODO: Implement RevenueCat purchase flow when ready
    return const PurchaseResult(
        success: false, errorMessage: 'RevenueCat not yet configured');
  }

  /// Purchase a subscription by product ID
  Future<PurchaseResult> purchaseSubscription(String productId) async {
    // DEV STUB
    return const PurchaseResult(
        success: false, errorMessage: 'RevenueCat not yet configured');
  }

  /// Purchase a coin package
  Future<PurchaseResult> purchaseCoins(CoinPackage package) async {
    // DEV STUB
    return const PurchaseResult(
        success: false, errorMessage: 'RevenueCat not yet configured');
  }

  /// Restore purchases
  Future<PurchaseResult> restorePurchases() async {
    // TODO: Implement restore purchases via RevenueCat
    return const PurchaseResult(
        success: false, errorMessage: 'RevenueCat not yet configured');
  }

  /// Get current entitlements
  Future<List<String>> getEntitlements() async {
    // TODO: Fetch active entitlements from RevenueCat
    return [];
  }
}
