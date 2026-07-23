import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/logger.dart';

/// Abstract payment gateway interface
abstract class IPaymentService {
  Future<void> initialize(String publishableKey);
  Future<Map<String, dynamic>> createPaymentIntent(
    String packageId,
    double amount,
  );
  Future<bool> confirmPayment(String clientSecret);
  Future<String?> createCheckoutSession(String packageId);
}

/// Production Stripe payment service
class StripePaymentService implements IPaymentService {
  static final StripePaymentService _instance =
      StripePaymentService._internal();

  factory StripePaymentService() {
    return _instance;
  }

  StripePaymentService._internal();

  bool _initialized = false;

  /// Initialize Stripe with publishable key
  @override
  Future<void> initialize(String publishableKey) async {
    if (_initialized) return;

    try {
      Stripe.publishableKey = publishableKey;
      if (!kIsWeb) {
        await Stripe.instance.applySettings();
      }
      _initialized = true;
      Logger.info('Stripe initialized successfully');
    } catch (e, st) {
      Logger.error('Stripe initialization failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Create a payment intent for direct payments
  @override
  Future<Map<String, dynamic>> createPaymentIntent(
    String packageId,
    double amount,
  ) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createPaymentIntent',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'packageId': packageId,
        'amount': (amount * 100).toInt(), // Convert to cents
        'userId': user.uid,
      });

      final data = Map<String, dynamic>.from(result.data);
      Logger.info('Payment intent created: ${data['id']}');
      return data;
    } catch (e, st) {
      Logger.error(
        'Failed to create payment intent',
        error: e,
        stackTrace: st,
      );
      await _reportToCrashlytics(e, st, 'createPaymentIntent');
      rethrow;
    }
  }

  /// Confirm payment using client secret (for web/mobile card form)
  @override
  Future<bool> confirmPayment(String clientSecret) async {
    try {
      if (kIsWeb) {
        // On web, use Stripe.js via cloud functions
        return await _confirmPaymentViaFunction(clientSecret);
      } else {
        // On mobile, use native Stripe SDK
        await Stripe.instance.confirmPaymentSheetPayment();
        return true;
      }
    } catch (e, st) {
      Logger.error(
        'Payment confirmation failed',
        error: e,
        stackTrace: st,
      );
      await _reportToCrashlytics(e, st, 'confirmPayment');
      return false;
    }
  }

  /// Create checkout session for hosted payment (recommended for web)
  @override
  Future<String?> createCheckoutSession(String packageId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final callable = FirebaseFunctions.instance.httpsCallable(
        'createCheckoutSessionCallable',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'packageId': packageId,
        'userId': user.uid,
      });

      final data = Map<String, dynamic>.from(result.data);
      final url = data['url'] as String?;

      if (url == null) {
        throw Exception('No checkout URL returned from server');
      }

      Logger.info('Checkout session created');
      return url;
    } catch (e, st) {
      Logger.error(
        'Failed to create checkout session',
        error: e,
        stackTrace: st,
      );
      await _reportToCrashlytics(e, st, 'createCheckoutSession');
      return null;
    }
  }

  /// Confirm payment via cloud function (for web)
  Future<bool> _confirmPaymentViaFunction(String clientSecret) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'confirmPaymentIntent',
      );

      final result = await callable.call<Map<String, dynamic>>({
        'clientSecret': clientSecret,
      });

      final data = Map<String, dynamic>.from(result.data);
      final status = data['status'] as String?;

      return status == 'succeeded' || status == 'processing';
    } catch (e, st) {
      Logger.error(
        'Failed to confirm payment via function',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Report errors to Crashlytics
  Future<void> _reportToCrashlytics(
    Object error,
    StackTrace stackTrace,
    String context,
  ) async {
    if (!kIsWeb) {
      try {
        await FirebaseCrashlytics.instance.recordError(
          error,
          stackTrace,
          reason: 'Payment error in $context',
        );
      } catch (_) {
        // Silently fail if Crashlytics is not available
      }
    }
  }
}




