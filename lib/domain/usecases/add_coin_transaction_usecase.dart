import '../../models/coin_transaction_model.dart';
import '../../data/repositories/coin_transaction_repository.dart';

class AddCoinTransactionUseCase {
  final CoinTransactionRepository repository;
  AddCoinTransactionUseCase(this.repository);
  Future<void> call(CoinTransactionModel transaction) =>
      repository.addTransaction(transaction);
}
