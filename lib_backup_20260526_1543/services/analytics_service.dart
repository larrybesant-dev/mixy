import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  AnalyticsService({FirebaseAnalytics? analytics}) : _analytics = analytics;

  FirebaseAnalytics? _analytics;

  bool get _crashlyticsSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  FirebaseAnalytics? _resolveAnalytics() {
    if (_analytics != null) {
      return _analytics;
    }

    try {
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }

    return _analytics;
  }

  Future<void> logEvent(String name, {Map<String, Object>? params}) async {
    final analytics = _resolveAnalytics();
    if (analytics == null) {
      return;
    }
    try {
      await analytics.logEvent(name: name, parameters: params);
    } catch (_) {
      // Telemetry transport must never affect product flows.
    }
  }

  Future<void> setUserContext({String? userId}) async {
    final analytics = _resolveAnalytics();
    try {
      await analytics?.setUserId(id: userId);
    } catch (_) {
      // Ignore analytics transport issues.
    }

    if (!_crashlyticsSupported) {
      return;
    }

    try {
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (_) {
      // Ignore crash transport issues.
    }
  }

  Future<void> setUserProperty({required String name, String? value}) async {
    final analytics = _resolveAnalytics();
    if (analytics == null) {
      return;
    }
    try {
      await analytics.setUserProperty(name: name, value: value);
    } catch (_) {
      // Ignore analytics transport issues.
    }
  }

  Future<void> logLogin({String? method}) async {
    final analytics = _resolveAnalytics();
    if (analytics == null) {
      return;
    }
    await analytics.logLogin(loginMethod: method);
  }

  Future<void> logPurchase({required double value, String? currency}) async {
    final analytics = _resolveAnalytics();
    if (analytics == null) {
      return;
    }
    await analytics.logEvent(
      name: 'purchase',
      parameters: <String, Object>{
        'value': value,
        'currency': currency ?? 'usd',
      },
    );
  }

  Future<void> logViewItem({required String itemId, String? itemName}) async {
    final analytics = _resolveAnalytics();
    if (analytics == null) {
      return;
    }
    await analytics.logEvent(
      name: 'view_item',
      parameters: <String, Object>{
        'item_id': itemId,
        'item_name': itemName ?? '',
      },
    );
  }
}
