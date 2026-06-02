import '../../models/gift_model.dart';

abstract class GiftRepository {
  Future<List<GiftModel>> getGifts();
  Future<void> sendGift(GiftModel gift);
}
