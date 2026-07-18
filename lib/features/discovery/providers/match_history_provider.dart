import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../services/match_history_service.dart';
import '../models/match_history_models.dart';

// Match history service provider
final matchHistoryServiceProvider = Provider<MatchHistoryService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return MatchHistoryService(firestore: firestore);
});

// Stream of profile views (who viewed your profile)
final profileViewsProvider =
    StreamProvider.autoDispose.family<List<ProfileView>, String>((ref, userId) {
  final service = ref.watch(matchHistoryServiceProvider);
  return service.getProfileViewsStream(userId);
});

// Stream of swipe history (all your likes/passes)
final swipeHistoryProvider =
    StreamProvider.autoDispose.family<List<SwipeHistory>, String>((ref, userId) {
  final service = ref.watch(matchHistoryServiceProvider);
  return service.getSwipeHistoryStream(userId);
});

// Stream of mutual matches
final mutualMatchesProvider =
    StreamProvider.autoDispose.family<List<String>, String>((ref, userId) {
  final service = ref.watch(matchHistoryServiceProvider);
  return service.getMutualMatchesStream(userId);
});

// Get who liked you (future-based, for one-time queries)
final whoLikedYouProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, userId) async {
  final service = ref.watch(matchHistoryServiceProvider);
  return service.getWhoLikedYou(userId);
});

// Get count of likes
final likeCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, userId) async {
  final service = ref.watch(matchHistoryServiceProvider);
  return service.getLikeCount(userId);
});

// Match history controller
final matchHistoryControllerProvider =
    StateNotifierProvider<MatchHistoryController, AsyncValue<void>>((ref) {
  final service = ref.watch(matchHistoryServiceProvider);
  return MatchHistoryController(service);
});

class MatchHistoryController extends StateNotifier<AsyncValue<void>> {
  MatchHistoryController(this._service) : super(const AsyncValue.data(null));

  final MatchHistoryService _service;

  /// Record a profile view
  Future<void> recordProfileView({
    required String viewerId,
    required String viewedUserId,
    String? context,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _service.recordProfileView(
        viewerId: viewerId,
        viewedUserId: viewedUserId,
        context: context,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
