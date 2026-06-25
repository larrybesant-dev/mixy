import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/gift_service.dart';
import '../models/gift_model.dart';

/// Cache GiftService as a singleton
final giftServiceProvider = Provider<GiftService>((ref) {
  return GiftService();
});

/// Stream available gifts via cached service
final giftsProvider = StreamProvider<List<Gift>>((ref) {
  final giftService = ref.watch(giftServiceProvider);
  return giftService.streamGifts();
});
