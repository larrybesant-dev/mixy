// AdManager handles ad display and user preferences
class AdManager {
  // Show popup ad only for users without VIP entitlement.
  static bool shouldShowAds({required bool hasVipEntitlement}) {
    return !hasVipEntitlement;
  }
}
