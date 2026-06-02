import '../../models/gift_model.dart';
import '../../data/repositories/gift_repository.dart';

class SendGiftUseCase {
  final GiftRepository repository;
  SendGiftUseCase(this.repository);
  Future<void> call(GiftModel gift) => repository.sendGift(gift);
}
