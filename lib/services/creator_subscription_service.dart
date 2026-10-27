class CreatorSubscriptionOffer {
  const CreatorSubscriptionOffer({
    required this.creatorId,
    required this.enabled,
    required this.monthlyPriceCents,
    required this.currency,
    required this.benefits,
  });

  final String creatorId;
  final bool enabled;
  final int monthlyPriceCents;
  final String currency;
  final List<String> benefits;

  factory CreatorSubscriptionOffer.fromJson(Map<String, dynamic> json) {
    return CreatorSubscriptionOffer(
      creatorId: (json['creatorId'] as String? ?? '').trim(),
      enabled: json['enabled'] == true,
      monthlyPriceCents: (json['monthlyPriceCents'] as num?)?.toInt() ?? 299,
      currency: (json['currency'] as String? ?? 'usd').trim().toLowerCase(),
      benefits: (json['benefits'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<String>()
          .map((benefit) => benefit.trim())
          .where((benefit) => benefit.isNotEmpty)
          .toList(growable: false),
    );
  }
}

class CreatorSubscriptionMembership {
  const CreatorSubscriptionMembership({
    required this.status,
    required this.cancelAtPeriodEnd,
    this.currentPeriodEnd,
  });

  final String status;
  final bool cancelAtPeriodEnd;
  final DateTime? currentPeriodEnd;

  bool get isActive => status == 'active' || status == 'trialing';

  factory CreatorSubscriptionMembership.fromJson(Map<String, dynamic> json) {
    final periodEnd = json['currentPeriodEnd'];
    DateTime? parsedPeriodEnd;
    if (periodEnd is String) {
      parsedPeriodEnd = DateTime.tryParse(periodEnd);
    } else if (periodEnd is num) {
      parsedPeriodEnd = DateTime.fromMillisecondsSinceEpoch(
        periodEnd.toInt() * 1000,
        isUtc: true,
      );
    }

    return CreatorSubscriptionMembership(
      status: (json['status'] as String? ?? 'inactive').trim().toLowerCase(),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
      currentPeriodEnd: parsedPeriodEnd,
    );
  }
}

class CreatorSubscriptionOverview {
  const CreatorSubscriptionOverview({
    required this.isOwner,
    required this.offer,
    required this.connectOnboardingComplete,
    required this.subscriberCount,
    this.analytics = const CreatorSubscriptionAnalytics(
      activeCount: 0,
      cancelingCount: 0,
      monthlyGrossCents: 0,
      estimatedPlatformFeeCents: 0,
      estimatedCreatorNetBeforeStripeCents: 0,
    ),
    this.recentActivity = const <CreatorSubscriberActivity>[],
    this.membership,
  });

  final bool isOwner;
  final CreatorSubscriptionOffer offer;
  final bool connectOnboardingComplete;
  final int subscriberCount;
  final CreatorSubscriptionAnalytics analytics;
  final List<CreatorSubscriberActivity> recentActivity;
  final CreatorSubscriptionMembership? membership;

  factory CreatorSubscriptionOverview.fromJson(Map<String, dynamic> json) {
    final offerJson = Map<String, dynamic>.from(
      json['offer'] as Map? ?? const <String, dynamic>{},
    );
    final connectJson = Map<String, dynamic>.from(
      json['connectStatus'] as Map? ?? const <String, dynamic>{},
    );
    final membershipJson = json['subscription'];

    return CreatorSubscriptionOverview(
      isOwner: json['isOwner'] == true,
      offer: CreatorSubscriptionOffer.fromJson(offerJson),
      connectOnboardingComplete:
          connectJson['onboardingComplete'] == true ||
          json['connectOnboardingComplete'] == true,
      subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
      analytics: CreatorSubscriptionAnalytics.fromJson(
        Map<String, dynamic>.from(
          json['analytics'] as Map? ?? const <String, dynamic>{},
        ),
      ),
      recentActivity:
          (json['recentSubscriberActivity'] as List<dynamic>? ??
                  const <dynamic>[])
              .whereType<Map>()
              .map(
                (item) => CreatorSubscriberActivity.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false),
      membership: membershipJson is Map
          ? CreatorSubscriptionMembership.fromJson(
              Map<String, dynamic>.from(membershipJson),
            )
          : null,
    );
  }
}

class CreatorSubscriptionAnalytics {
  const CreatorSubscriptionAnalytics({
    required this.activeCount,
    required this.cancelingCount,
    required this.monthlyGrossCents,
    required this.estimatedPlatformFeeCents,
    required this.estimatedCreatorNetBeforeStripeCents,
  });

  final int activeCount;
  final int cancelingCount;
  final int monthlyGrossCents;
  final int estimatedPlatformFeeCents;
  final int estimatedCreatorNetBeforeStripeCents;

  factory CreatorSubscriptionAnalytics.fromJson(Map<String, dynamic> json) {
    return CreatorSubscriptionAnalytics(
      activeCount: (json['activeCount'] as num?)?.toInt() ?? 0,
      cancelingCount: (json['cancelingCount'] as num?)?.toInt() ?? 0,
      monthlyGrossCents: (json['monthlyGrossCents'] as num?)?.toInt() ?? 0,
      estimatedPlatformFeeCents:
          (json['estimatedPlatformFeeCents'] as num?)?.toInt() ?? 0,
      estimatedCreatorNetBeforeStripeCents:
          (json['estimatedCreatorNetBeforeStripeCents'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreatorSubscriberActivity {
  const CreatorSubscriberActivity({
    required this.subscriberId,
    required this.displayName,
    required this.status,
    required this.cancelAtPeriodEnd,
  });

  final String subscriberId;
  final String displayName;
  final String status;
  final bool cancelAtPeriodEnd;

  factory CreatorSubscriberActivity.fromJson(Map<String, dynamic> json) {
    return CreatorSubscriberActivity(
      subscriberId: (json['subscriberId'] as String? ?? '').trim(),
      displayName:
          (json['displayName'] as String? ?? 'MixVy member').trim(),
      status: (json['status'] as String? ?? 'inactive').trim(),
      cancelAtPeriodEnd: json['cancelAtPeriodEnd'] == true,
    );
  }
}

class CreatorMarketplaceEntry {
  const CreatorMarketplaceEntry({
    required this.creatorId,
    required this.displayName,
    required this.avatarUrl,
    required this.offer,
    required this.subscriberCount,
  });

  final String creatorId;
  final String displayName;
  final String avatarUrl;
  final CreatorSubscriptionOffer offer;
  final int subscriberCount;

  factory CreatorMarketplaceEntry.fromJson(Map<String, dynamic> json) {
    final offerJson = Map<String, dynamic>.from(
      json['offer'] as Map? ?? json,
    );
    return CreatorMarketplaceEntry(
      creatorId: (json['creatorId'] as String? ?? '').trim(),
      displayName: (json['displayName'] as String? ?? 'MixVy creator').trim(),
      avatarUrl: (json['avatarUrl'] as String? ?? '').trim(),
      offer: CreatorSubscriptionOffer.fromJson(offerJson),
      subscriberCount: (json['subscriberCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class CreatorSubscriberUpdate {
  const CreatorSubscriberUpdate({
    required this.id,
    required this.creatorId,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String creatorId;
  final String text;
  final DateTime? createdAt;

  factory CreatorSubscriberUpdate.fromJson(Map<String, dynamic> json) {
    final rawCreatedAt = json['createdAt'];
    DateTime? createdAt;
    if (rawCreatedAt is String) {
      createdAt = DateTime.tryParse(rawCreatedAt);
    } else if (rawCreatedAt is num) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(
        rawCreatedAt.toInt() * 1000,
        isUtc: true,
      );
    }
    return CreatorSubscriberUpdate(
      id: (json['id'] as String? ?? '').trim(),
      creatorId: (json['creatorId'] as String? ?? '').trim(),
      text: (json['text'] as String? ?? '').trim(),
      createdAt: createdAt,
    );
  }
}

abstract class CreatorSubscriptionService {
  Future<String> createStripeConnectOnboardingLink();

  Future<CreatorSubscriptionOverview> getCreatorSubscriptionOverview(
    String creatorId,
  );

  Future<CreatorSubscriptionOverview> saveCreatorSubscriptionOffer({
    required bool enabled,
    required int monthlyPriceCents,
    required List<String> benefits,
  });

  Future<String> createCreatorSubscriptionCheckout(String creatorId);

  Future<CreatorSubscriptionOverview> cancelCreatorSubscription(
    String creatorId,
  );

  Future<List<CreatorMarketplaceEntry>> listCreatorSubscriptionMarketplace({
    String query,
  });

  Future<CreatorSubscriberUpdate> publishCreatorSubscriberUpdate(String text);

  Future<List<CreatorSubscriberUpdate>> listCreatorSubscriberUpdates(
    String creatorId,
  );

  Future<void> reportCreatorSubscriberUpdate({
    required String updateId,
    required String reason,
    String details,
  });
}
