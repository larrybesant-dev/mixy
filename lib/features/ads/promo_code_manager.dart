// Handles promo codes for free ad spots
class PromoCodeManager {
  static const bool _promoCodesEnabled = false;

  // Feature-flagged off until backend validation is wired.
  static Future<bool> validatePromoCode(String code) async {
    if (!_promoCodesEnabled) {
      return false;
    }
    return false;
  }

  // Feature-flagged off until backend write and server-side validation are wired.
  static Future<void> grantFreeAd(String businessId) async {
    if (!_promoCodesEnabled) {
      return;
    }
  }
}




