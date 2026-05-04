import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/payment_api.dart';
// Unused import removed: 'payment_api_provider.dart';

/// Provide a stream of CoinTransaction for a given userId
final coinTransactionStreamProvider = StreamProvider.autoDispose
    .family<List<CoinTransaction>, String>((ref, userId) {
      // Removed unused variable: paymentApi
      return PaymentApi.getTransactions(userId);
    });
