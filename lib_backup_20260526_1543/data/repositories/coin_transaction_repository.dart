import '../../models/coin_transaction_model.dart';

abstract class CoinTransactionRepository {
  Future<List<CoinTransactionModel>> getTransactions(String userId);
  Future<void> addTransaction(CoinTransactionModel transaction);
}
