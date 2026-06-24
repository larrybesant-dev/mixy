/// Membership Service
///
/// Handles Firestore integration for membership and coin data.
/// Syncs RevenueCat entitlements with Firestore user documents.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../models/membership_tier.dart';
import '../models/coin_package.dart';
import 'revenuecat_service.dart';
import '../../../core/analytics/analytics_service.dart' as core_analytics;
import '../../../core/crashlytics/crashlytics_service.dart';

/// Membership service for Firestore integration
class MembershipService {
  static MembershipService? _instance;
  static MembershipService get instance => _instance ??= MembershipService._();

  MembershipService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  final core_analytics.AnalyticsService _coreAnalytics =
      core_analytics.AnalyticsService.instance;
  final CrashlyticsService _crashlytics = CrashlyticsService.instance;

  String? _currentUserId;
  MembershipTier _currentTier = MembershipTier.free;
  int _coinBalance = 0;
  StreamSubscription? _tierSubscription;
  StreamController<MembershipTier>? _membershipStreamController;
  StreamController<int>? _coinBalanceStreamController;

  // Getters
  MembershipTier get currentTier => _currentTier;
  int get coinBalance => _coinBalance;

  /// Stream of membership tier changes
  Stream<MembershipTier> get membershipStream {
    _membershipStreamController ??=
        StreamController<MembershipTier>.broadcast();
    return _membershipStreamController!.stream;
  }

  /// Stream of coin balance changes
  Stream<int> get coinBalanceStream {
    _coinBalanceStreamController ??= StreamController<int>.broadcast();
    return _coinBalanceStreamController!.stream;
  }

  /// Initialize the membership service
  Future<void> initialize(String userId) async {
    _currentUserId = userId;

    try {
      debugPrint('ðŸŽ« [Membership] Initializing for user: $userId');

      // Initialize RevenueCat
      await RevenueCatService.instance.initialize(userId);

      // Listen to RevenueCat tier changes
      _tierSubscription = RevenueCatService.instance.tierStream.listen((tier) {
        _syncMembershipToFirestore(tier);
      });

      // Load current data from Firestore
      await _loadUserMembershipData();

      debugPrint('âœ… [Membership] Initialized successfully');
    } catch (e) {
      debugPrint('âŒ [Membership] Init error: $e');
    }
  }

  /// Load user membership data from Firestore
  Future<void> _loadUserMembershipData() async {
    if (_currentUserId == null) return;

    try {
      final doc =
          await _firestore.collection('users').doc(_currentUserId).get();
      final data = doc.data();

      if (data != null) {
        _currentTier = MembershipTier.fromFirestore(data['membershipTier']);
        _coinBalance = data['coinBalance'] ?? 0;

        _membershipStreamController?.add(_currentTier);
        _coinBalanceStreamController?.add(_coinBalance);
      }
    } catch (e) {
      debugPrint('âŒ [Membership] Failed to load user data: $e');
    }
  }

  /// Sync membership tier to Firestore
  Future<void> _syncMembershipToFirestore(MembershipTier tier) async {
    if (_currentUserId == null) return;

    try {
      final previousTier = _currentTier;
      _currentTier = tier;

      await _firestore.collection('users').doc(_currentUserId).update({
        'membershipTier': tier.firestoreValue,
        'lastMembershipUpdate': FieldValue.serverTimestamp(),
      });

      _membershipStreamController?.add(tier);

      // Log analytics events
      if (tier.isHigherThan(previousTier)) {
        await _logEvent('membership_upgraded', {
          'previous_tier': previousTier.firestoreValue,
          'new_tier': tier.firestoreValue,
        });
        await _coreAnalytics.logMembershipChanged(
          tier: tier.firestoreValue,
          previousTier: previousTier.firestoreValue,
        );
        // Track VIP conversion funnel
        if (tier == MembershipTier.vip || tier == MembershipTier.vipPlus) {
          await _coreAnalytics.logVipConversionFunnelStep(
              step: 'converted', tier: tier.firestoreValue);
        }
      } else if (previousTier.isHigherThan(tier)) {
        await _logEvent('membership_downgraded', {
          'previous_tier': previousTier.firestoreValue,
          'new_tier': tier.firestoreValue,
        });
        await _coreAnalytics.logMembershipChanged(
          tier: tier.firestoreValue,
          previousTier: previousTier.firestoreValue,
        );
      }

      debugPrint(
          'âœ… [Membership] Synced tier to Firestore: ${tier.displayName}');
    } catch (e) {
      debugPrint('âŒ [Membership] Failed to sync tier: $e');
    }
  }

  /// Update coin balance in Firestore
  Future<bool> updateCoinBalance(int change, CoinTransactionType type,
      {String? description}) async {
    if (_currentUserId == null) return false;

    try {
      final newBalance = _coinBalance + change;
      if (newBalance < 0) {
        debugPrint('âš ï¸ [Membership] Insufficient coins');
        return false;
      }

      // Update balance
      await _firestore.collection('users').doc(_currentUserId).update({
        'coinBalance': newBalance,
      });

      // Log transaction
      await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('coinTransactions')
          .add({
        'type': type.value,
        'amount': change,
        'description': description,
        'balanceAfter': newBalance,
        'timestamp': FieldValue.serverTimestamp(),
      });

      _coinBalance = newBalance;
      _coinBalanceStreamController?.add(_coinBalance);

      debugPrint(
          'âœ… [Membership] Coin balance updated: $change -> $newBalance');
      return true;
    } catch (e) {
      debugPrint('âŒ [Membership] Failed to update coins: $e');
      return false;
    }
  }

  /// Add coins (for purchases)
  Future<bool> addCoins(int amount, {String? description}) async {
    return updateCoinBalance(
      amount,
      CoinTransactionType.purchase,
      description: description ?? 'Coin purchase',
    );
  }

  /// Deduct coins (for gifts, spotlight, etc.)
  Future<bool> deductCoins(int amount, CoinTransactionType type,
      {String? description}) async {
    if (_coinBalance < amount) {
      debugPrint(
          'âš ï¸ [Membership] Insufficient coins: $_coinBalance < $amount');
      return false;
    }
    return updateCoinBalance(-amount, type, description: description);
  }

  /// Add bonus coins (for membership rewards)
  Future<bool> addBonusCoins(int amount, {String? description}) async {
    return updateCoinBalance(
      amount,
      CoinTransactionType.bonus,
      description: description ?? 'Bonus coins',
    );
  }

  /// Check if user can afford a purchase
  bool canAfford(int amount) => _coinBalance >= amount;

  /// Check if user has specific membership access
  bool hasAccess(MembershipTier requiredTier) {
    return _currentTier.includes(requiredTier);
  }

  /// Check if user can join VIP rooms
  bool get canJoinVipRooms => hasAccess(MembershipTier.vip);

  /// Check if user can join VIP+ rooms
  bool get canJoinVipPlusRooms => hasAccess(MembershipTier.vipPlus);

  /// Get spotlight multiplier based on membership
  int get spotlightMultiplier {
    switch (_currentTier) {
      case MembershipTier.free:
        return 1;
      case MembershipTier.vip:
        return 2;
      case MembershipTier.vipPlus:
        return 4;
    }
  }

  /// Get daily room join limit
  int get dailyRoomJoinLimit {
    switch (_currentTier) {
      case MembershipTier.free:
        return 5;
      case MembershipTier.vip:
      case MembershipTier.vipPlus:
        return -1; // Unlimited
    }
  }

  /// Get coin transaction history
  Future<List<CoinTransaction>> getCoinTransactionHistory(
      {int limit = 20}) async {
    if (_currentUserId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(_currentUserId)
          .collection('coinTransactions')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CoinTransaction.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('âŒ [Membership] Failed to get transaction history: $e');
      return [];
    }
  }

  /// Log analytics event
  Future<void> _logEvent(String name, [Map<String, Object>? params]) async {
    try {
      await _analytics.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('âš ï¸ [Analytics] Failed to log event: $e');
    }
  }

  /// Log paywall viewed event
  Future<void> logPaywallViewed() async {
    await _logEvent('paywall_viewed', {
      'current_tier': _currentTier.firestoreValue,
    });
  }

  /// Log coin purchase started
  Future<void> logCoinPurchaseStarted(CoinPackage package) async {
    await _logEvent('coin_purchase_started', {
      'package_id': package.id,
      'coins': package.coins,
      'price': package.priceValue,
    });
    await _coreAnalytics.logCoinPurchaseStarted(
      packageId: package.id,
      coinAmount: package.coins,
      price: package.priceValue,
    );
  }

  /// Log coin purchase completed
  Future<void> logCoinPurchaseCompleted(
      CoinPackage package, int totalCoins) async {
    await _logEvent('coin_purchase_completed', {
      'package_id': package.id,
      'coins': totalCoins,
      'price': package.priceValue,
    });
    await _coreAnalytics.logCoinPurchaseCompleted(
      packageId: package.id,
      coinAmount: totalCoins,
      price: package.priceValue,
    );
  }

  /// Log coin purchase failed
  Future<void> logCoinPurchaseFailed(CoinPackage package, String error) async {
    await _logEvent('coin_purchase_failed', {
      'package_id': package.id,
      'error': error,
    });
    await _coreAnalytics.logCoinPurchaseFailed(
      packageId: package.id,
      error: error,
    );
    await _crashlytics.logPaymentFailure(
      productId: package.id,
      error: error,
    );
  }

  /// Log VIP room attempt blocked
  Future<void> logVipRoomBlocked() async {
    await _logEvent('vip_room_attempt_blocked', {
      'current_tier': _currentTier.firestoreValue,
    });
  }

  /// Log spotlight attempt blocked
  Future<void> logSpotlightBlocked() async {
    await _logEvent('spotlight_attempt_blocked', {
      'current_tier': _currentTier.firestoreValue,
    });
  }

  /// Clean up resources
  void dispose() {
    _tierSubscription?.cancel();
    _membershipStreamController?.close();
    _coinBalanceStreamController?.close();
    _currentUserId = null;
  }
}
