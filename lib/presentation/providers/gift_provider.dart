// Duplicate import removed: 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/gift_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final giftListProvider = StateProvider<List<GiftModel>>((ref) => []);

/// Holds the currently selected gift for sending
final selectedGiftProvider = StateProvider<GiftModel?>((ref) => null);




