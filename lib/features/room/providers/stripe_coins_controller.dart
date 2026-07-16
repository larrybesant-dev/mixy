import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:uuid/uuid.dart';

import '../models/coin_package.dart';

/// Handles Stripe payment processing for coin purchases.
class StripeCoinsController {
  final FirebaseFunctions _functions;

  StripeCoinsController({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  /// Purchase a coin package via Stripe.
  /// Returns the transaction ID on success.
  Future<String> purchaseCoinPackage({
    required CoinPackage package,
  }) async {
    // Step 1: Create payment intent
    final idempotencyKey = const Uuid().v4();
    final intentResponse = await _functions
        .httpsCallable('createPaymentIntent')
        .call<Map<String, dynamic>>({
      'recipientId': '',
      'currency': 'usd',
      'amount': package.priceUSD,
      'idempotencyKey': idempotencyKey,
    });

    final clientSecret = intentResponse.data['clientSecret'] as String;
    final paymentIntentId = intentResponse.data['paymentIntentId'] as String;

    // Step 2: Initialize Stripe payment
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'MixVy',
        style: ThemeMode.dark,
      ),
    );

    // Step 3: Present payment sheet
    await Stripe.instance.presentPaymentSheet();

    // Step 4: Record successful payment on backend
    final recordResponse = await _functions
        .httpsCallable('recordStripePaymentSuccess')
        .call<Map<String, dynamic>>({
      'recipientId': '',
      'amount': package.priceUSD,
      'paymentIntentId': paymentIntentId,
      'idempotencyKey': idempotencyKey,
    });

    final transactionId = recordResponse.data['transactionId'] as String;
    return transactionId;
  }
}
