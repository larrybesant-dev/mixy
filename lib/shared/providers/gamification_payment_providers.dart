import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/gamification/gamification_service.dart';
import '../../services/gamification/badge_service.dart';
import '../../services/payments/payment_service.dart';
import '../../services/payments/subscription_service.dart';
import '../../services/analytics/analytics_service.dart';
import '../models/user_level.dart';
import '../models/user_streak.dart';
import '../models/achievement.dart';
import '../models/subscription.dart';
import 'auth_providers.dart';

/// Service providers
final gamificationServiceProvider =
    Provider<GamificationService>((ref) => GamificationService());

final badgeServiceProvider = Provider<BadgeService>((ref) => BadgeService());

final paymentServiceProvider =
    Provider<PaymentService>((ref) => PaymentService());

final subscriptionServiceProvider =
    Provider<SubscriptionService>((ref) => SubscriptionService());

final analyticsServiceProvider =
    Provider<AnalyticsService>((ref) => AnalyticsService());

/// ============================================================================
/// GAMIFICATION PROVIDERS
/// ============================================================================

/// User level provider
final userLevelProvider = StreamProvider<UserLevel?>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield null;
    return;
  }

  final gamificationService = ref.watch(gamificationServiceProvider);

  try {
    final level = await gamificationService.getUserLevel(currentUser.id);
    yield level;

    // Poll for updates
    await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
      final updated = await gamificationService.getUserLevel(currentUser.id);
      yield updated;
    }
  } catch (e) {
    yield null;
  }
});

/// User streak provider
final userStreakProvider = StreamProvider<UserStreak?>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield null;
    return;
  }

  final gamificationService = ref.watch(gamificationServiceProvider);

  try {
    final streak = await gamificationService.getUserStreak(currentUser.id);
    yield streak;

    // Poll for updates
    await for (final _ in Stream.periodic(const Duration(minutes: 1))) {
      final updated = await gamificationService.getUserStreak(currentUser.id);
      yield updated;
    }
  } catch (e) {
    yield null;
  }
});

/// User badges provider
final userBadgesProvider = StreamProvider<List<UserBadge>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  final badgeService = ref.watch(badgeServiceProvider);

  try {
    final badges = await badgeService.getUserBadges(currentUser.id);
    yield badges;
  } catch (e) {
    yield [];
  }
});

/// Available achievements provider
final availableAchievementsProvider =
    FutureProvider<List<Achievement>>((ref) async {
  final gamificationService = ref.watch(gamificationServiceProvider);
  return gamificationService.getAvailableAchievements();
});

/// User XP provider
final userXPProvider = StreamProvider<int>((ref) async* {
  final level = ref.watch(userLevelProvider).value;
  yield level?.currentXP ?? 0;
});

/// XP to next level provider
final xpToNextLevelProvider = StreamProvider<int>((ref) async* {
  final level = ref.watch(userLevelProvider).value;
  if (level == null) {
    yield 0;
    return;
  }

  yield level.xpToNextLevel;
});

/// Leaderboard provider
final leaderboardProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>(
        (ref, category) async {
  final gamificationService = ref.watch(gamificationServiceProvider);
  return gamificationService.getLeaderboard(category, 50);
});

/// Gamification controller
final gamificationControllerProvider =
    NotifierProvider<GamificationController, AsyncValue<void>>(() {
  return GamificationController();
});

class GamificationController extends Notifier<AsyncValue<void>> {
  late final GamificationService _gamificationService;

  @override
  AsyncValue<void> build() {
    _gamificationService = ref.watch(gamificationServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Award XP to user
  Future<void> awardXP(int amount, String reason) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _gamificationService.awardXP(currentUser.id, amount, reason);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Check and update daily streak
  Future<void> checkDailyStreak() async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _gamificationService.checkDailyStreak(currentUser.id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Unlock achievement
  Future<void> unlockAchievement(String achievementId) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _gamificationService.unlockAchievement(
        currentUser.id,
        achievementId,
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Award badge
  Future<void> awardBadge(String badgeId) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final badgeService = ref.read(badgeServiceProvider);
      await badgeService.awardBadge(userId: currentUser.id, badgeId: badgeId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}

/// ============================================================================
/// PAYMENT PROVIDERS
/// ============================================================================

/// Payment methods provider
final paymentMethodsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return [];

  final paymentService = ref.watch(paymentServiceProvider);
  final result = await paymentService.getPaymentMethods(currentUser.id);
  return result.cast<Map<String, dynamic>>();
});

/// Payment history provider
final paymentHistoryProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) {
    return [];
  }

  final paymentService = ref.watch(paymentServiceProvider);

  try {
    final result = await paymentService.getPaymentHistory(currentUser.id);
    return result.cast<Map<String, dynamic>>();
  } catch (e) {
    return [];
  }
});

/// Payment controller
final paymentControllerProvider =
    NotifierProvider<PaymentController, AsyncValue<void>>(() {
  return PaymentController();
});

class PaymentController extends Notifier<AsyncValue<void>> {
  late final PaymentService _paymentService;

  @override
  AsyncValue<void> build() {
    _paymentService = ref.watch(paymentServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Process payment
  Future<bool> processPayment({
    required double amount,
    required String currency,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // processPayment expects: userId, paymentMethodId, amount
      final result = await _paymentService.processPayment(
        currentUser.id,
        'default_payment_method',
        amount.toInt(),
      );

      state = const AsyncValue.data(null);
      return result;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return false;
    }
  }

  /// Add payment method
  Future<void> addPaymentMethod(Map<String, dynamic> paymentMethod) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _paymentService.addPaymentMethod(currentUser.id, paymentMethod);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Remove payment method
  Future<void> removePaymentMethod(String paymentMethodId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _paymentService.removePaymentMethod(
        currentUser.id,
        paymentMethodId,
      );
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Refund payment
  Future<void> refundPayment(String paymentId) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) throw Exception('User not authenticated');

      await _paymentService.refundPayment(currentUser.id, paymentId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}

/// ============================================================================
/// ANALYTICS PROVIDERS
/// ============================================================================

/// Analytics controller
final analyticsControllerProvider =
    NotifierProvider<AnalyticsController, AsyncValue<void>>(() {
  return AnalyticsController();
});

class AnalyticsController extends Notifier<AsyncValue<void>> {
  late final AnalyticsService _analyticsService;

  @override
  AsyncValue<void> build() {
    _analyticsService = ref.watch(analyticsServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Log event
  Future<void> logEvent(
      String eventName, Map<String, dynamic>? parameters) async {
    try {
      await _analyticsService.logEvent(
        eventName,
        parameters: parameters?.cast<String, Object>(),
      );
    } catch (e) {
      // Don't fail on analytics errors
    }
  }

  /// Log screen view
  Future<void> logScreenView(String screenName, String screenClass) async {
    try {
      await _analyticsService.setCurrentScreen(screenName);
    } catch (e) {
      // Don't fail on analytics errors
    }
  }

  /// Set user properties
  Future<void> setUserProperties(Map<String, dynamic> properties) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) return;

      await _analyticsService.setUserId(currentUser.id);
      for (final entry in properties.entries) {
        await _analyticsService.setUserProperty(
            entry.key, entry.value.toString());
      }
    } catch (e) {
      // Don't fail on analytics errors
    }
  }

  /// Log purchase
  Future<void> logPurchase({
    required double value,
    required String currency,
    required String itemId,
    String? itemName,
  }) async {
    try {
      final params = <String, Object>{
        'value': value,
        'currency': currency,
        'item_id': itemId,
      };
      if (itemName != null) {
        params['item_name'] = itemName;
      }
      await _analyticsService.logEvent('purchase', parameters: params);
    } catch (e) {
      // Don't fail on analytics errors
    }
  }

  /// Log level up
  Future<void> logLevelUp(int level) async {
    try {
      await _analyticsService.logEvent('level_up', parameters: {
        'level': level,
        'character': 'user',
      });
    } catch (e) {
      // Don't fail on analytics errors
    }
  }

  /// Log share
  Future<void> logShare(String contentType, String itemId) async {
    try {
      await _analyticsService.logEvent('share', parameters: {
        'content_type': contentType,
        'item_id': itemId,
      });
    } catch (e) {
      // Don't fail on analytics errors
    }
  }
}

/// User analytics provider (dashboard stats)
final userAnalyticsProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield {};
    return;
  }

  // Aggregate user analytics data
  yield {
    'totalRoomsJoined': 0,
    'totalRoomsCreated': 0,
    'totalMessagesSet': 0,
    'totalMatchesMade': 0,
    'totalEventtsAttended': 0,
    'totalCoinsEarned': 0,
    'totalCoinsSpent': 0,
    'accountAge': DateTime.now().difference(currentUser.createdAt).inDays,
  };
});

/// ============================================================================
/// SUBSCRIPTION PROVIDERS
/// ============================================================================

/// User coin balance provider
final userCoinBalanceProvider = StreamProvider<int>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value(0);

  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.coinBalanceStream(currentUser.id);
});

/// User subscription provider - real-time stream
final userSubscriptionProvider = StreamProvider<UserSubscription?>((ref) {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) return Stream.value(null);

  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.getUserSubscriptionStream(currentUser.id);
});

/// Has active subscription provider
final hasActiveSubscriptionProvider = FutureProvider<bool>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return false;

  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.hasActiveSubscription(currentUser.id);
});

/// Subscription packages provider
final subscriptionPackagesProvider =
    FutureProvider<List<SubscriptionPackage>>((ref) async {
  // Return hardcoded packages for now
  // TODO: Fetch from Firestore or backend
  return [
    SubscriptionPackage(
      id: 'basic_monthly',
      tier: SubscriptionTier.basic,
      duration: SubscriptionDuration.monthly,
      price: 4.99,
      features: [
        'Priority matching',
        'Advanced filters',
        'Read receipts',
        'Typing indicators',
        'Custom profile themes',
        'HD voice quality',
      ],
    ),
    SubscriptionPackage(
      id: 'premium_monthly',
      tier: SubscriptionTier.premium,
      duration: SubscriptionDuration.monthly,
      price: 9.99,
      features: [
        'All Basic features',
        'Unlimited rooms',
        'Screen sharing',
        'Gift animations',
        'Badge showcase',
        'Early access to features',
      ],
    ),
    SubscriptionPackage(
      id: 'vip_monthly',
      tier: SubscriptionTier.vip,
      duration: SubscriptionDuration.monthly,
      price: 19.99,
      features: [
        'All Premium features',
        'Exclusive badges',
        'Priority support',
        'Custom emojis',
        'Ad-free experience',
        'VIP-only rooms',
      ],
    ),
  ];
});

/// Subscription controller
final subscriptionControllerProvider =
    NotifierProvider<SubscriptionController, AsyncValue<void>>(() {
  return SubscriptionController();
});

class SubscriptionController extends Notifier<AsyncValue<void>> {
  late final SubscriptionService _subscriptionService;

  @override
  AsyncValue<void> build() {
    _subscriptionService = ref.watch(subscriptionServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Subscribe to a package
  Future<void> subscribe(SubscriptionPackage package) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _subscriptionService.subscribe(
        userId: currentUser.id,
        package: package,
      );

      // Invalidate subscription provider to refresh
      ref.invalidate(userSubscriptionProvider);

      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Cancel subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    state = const AsyncValue.loading();
    try {
      await _subscriptionService.cancelSubscription(subscriptionId);

      // Invalidate subscription provider to refresh
      ref.invalidate(userSubscriptionProvider);

      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Renew subscription - extends subscription by 30 days
  Future<void> renewSubscription(String subscriptionId) async {
    state = const AsyncValue.loading();
    try {
      await _subscriptionService.renewSubscription(
          subscriptionId, const Duration(days: 30));

      // Invalidate subscription provider to refresh
      ref.invalidate(userSubscriptionProvider);

      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}
