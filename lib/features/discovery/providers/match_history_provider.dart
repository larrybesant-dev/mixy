import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../services/match_history_service.dart';
import '../models/match_history_models.dart';

// Match history service provider
final matchHistoryServiceProvider = Provider<MatchHistoryService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return MatchHistoryService(firestore: firestore);
});

class _ProfileViewsNotifier extends StateNotifier<AsyncValue<List<ProfileView>>> {
  _ProfileViewsNotifier(this._service, this._userId)
    : super(const AsyncValue.loading()) {
    _subscription = _service.getProfileViewsStream(_userId).listen(
      (value) => state = AsyncValue.data(value),
      onError: (error, stackTrace) => state = AsyncValue.error(error, stackTrace),
    );
  }

  final MatchHistoryService _service;
  final String _userId;
  late final StreamSubscription<List<ProfileView>> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _SwipeHistoryNotifier extends StateNotifier<AsyncValue<List<SwipeHistory>>> {
  _SwipeHistoryNotifier(this._service, this._userId)
    : super(const AsyncValue.loading()) {
    _subscription = _service.getSwipeHistoryStream(_userId).listen(
      (value) => state = AsyncValue.data(value),
      onError: (error, stackTrace) => state = AsyncValue.error(error, stackTrace),
    );
  }

  final MatchHistoryService _service;
  final String _userId;
  late final StreamSubscription<List<SwipeHistory>> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

class _MutualMatchesNotifier extends StateNotifier<AsyncValue<List<String>>> {
  _MutualMatchesNotifier(this._service, this._userId)
    : super(const AsyncValue.loading()) {
    _subscription = _service.getMutualMatchesStream(_userId).listen(
      (value) => state = AsyncValue.data(value),
      onError: (error, stackTrace) => state = AsyncValue.error(error, stackTrace),
    );
  }

  final MatchHistoryService _service;
  final String _userId;
  late final StreamSubscription<List<String>> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

// Live profile views (who viewed your profile)
final profileViewsProvider = StateNotifierProvider.autoDispose
    .family<_ProfileViewsNotifier, AsyncValue<List<ProfileView>>, String>((
      ref,
      userId,
    ) {
      final service = ref.watch(matchHistoryServiceProvider);
      return _ProfileViewsNotifier(service, userId);
    });

// Live swipe history (all your likes/passes)
final swipeHistoryProvider = StateNotifierProvider.autoDispose
    .family<_SwipeHistoryNotifier, AsyncValue<List<SwipeHistory>>, String>((
      ref,
      userId,
    ) {
      final service = ref.watch(matchHistoryServiceProvider);
      return _SwipeHistoryNotifier(service, userId);
    });

// Live mutual matches
final mutualMatchesProvider = StateNotifierProvider.autoDispose
    .family<_MutualMatchesNotifier, AsyncValue<List<String>>, String>((
      ref,
      userId,
    ) {
      final service = ref.watch(matchHistoryServiceProvider);
      return _MutualMatchesNotifier(service, userId);
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
