// lib/features/payments/repositories/i_payments_repository.dart
//
// Abstract contract for payment and coin operations.
import 'package:mixvy/shared/models/coin_transaction.dart';

abstract class IPaymentsRepository {
  /// Get current coin balance for [uid].
  Future<int> getCoinBalance(String uid);

  /// Watch coin balance stream for [uid].
  Stream<int> watchCoinBalance(String uid);

  /// Credit coins to a user's wallet.
  /// Should only be called after a successful purchase verification.
  Future<void> creditCoins({
    required String uid,
    required int amount,
    required String transactionId,
    required String source, // 'iap', 'promo', 'gift', etc.
  });

  /// Debit coins from a user's wallet.
  /// Throws if the balance is insufficient.
  Future<void> debitCoins({
    required String uid,
    required int amount,
    required String reason,
  });

  /// Transfer coins from one user to another (e.g. tip / gift).
  Future<void> transferCoins({
    required String fromUid,
    required String toUid,
    required int amount,
    required String reason,
  });

  /// Get paginated coin transaction history for [uid].
  Future<List<CoinTransaction>> getTransactionHistory(
    String uid, {
    int limit = 30,
    String? afterTransactionId,
  });
}

