import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/social/match_service.dart';
import '../models/match.dart';
import '../models/user_profile.dart';
import 'auth_providers.dart';

/// Service provider
final matchServiceProvider = Provider<MatchService>((ref) => MatchService());

/// User matches stream provider
final userMatchesProvider = StreamProvider<List<Match>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  // In production, this would be a Firestore stream query
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    try {
      // This is simplified - needs actual Firestore stream implementation
      yield [];
    } catch (e) {
      yield [];
    }
  }
});

/// Pending match requests provider
final pendingMatchRequestsProvider = StreamProvider<List<Match>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  // Query matches where status = pending and user is userId2
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    try {
      // This would query Firestore for pending matches
      yield [];
    } catch (e) {
      yield [];
    }
  }
});

/// Accepted matches provider
final acceptedMatchesProvider = StreamProvider<List<Match>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  // Query matches where status = accepted
  await for (final _ in Stream.periodic(const Duration(seconds: 5))) {
    try {
      yield [];
    } catch (e) {
      yield [];
    }
  }
});

/// Potential matches provider (users to swipe on)
final potentialMatchesProvider =
    StreamProvider<List<UserProfile>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  try {
    // This would query potential matches based on preferences
    // For now, return empty list
    yield [];
  } catch (e) {
    yield [];
  }
});

/// Match recommendations provider (async version for discovery page)
final matchRecommendationsProvider =
    FutureProvider<List<UserProfile>>((ref) async {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    return [];
  }

  try {
    // This would fetch recommended matches based on user preferences
    // For now, return empty list as placeholder
    return [];
  } catch (e) {
    return [];
  }
});

/// Match controller for match operations
final matchControllerProvider =
    NotifierProvider<MatchController, AsyncValue<Match?>>(() {
  return MatchController();
});

class MatchController extends Notifier<AsyncValue<Match?>> {
  late final MatchService _matchService;

  @override
  AsyncValue<Match?> build() {
    _matchService = ref.watch(matchServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Like a user (create match request)
  Future<void> likeUser(String userId) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _matchService.likeUser(currentUser.id, userId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Unlike a user
  Future<void> unlikeUser(String userId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _matchService.unlikeUser(currentUser.id, userId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Accept a match request
  Future<void> acceptMatch(String matchId) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update match status to accepted
      // This would be implemented in MatchService
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Reject a match request
  Future<void> rejectMatch(String matchId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Update match status to rejected
      // This would be implemented in MatchService
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Unmatch (remove match)
  Future<void> unmatch(String matchId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Delete match or set status to unmatched
      // This would be implemented in MatchService
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Alias methods for backward compatibility
  Future<void> like(String userId) => likeUser(userId);
  Future<void> accept(String matchId) => acceptMatch(matchId);
  Future<void> reject(String matchId) => rejectMatch(matchId);

  /// Check if user is liked
  Future<bool> isUserLiked(String userId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        return false;
      }

      return await _matchService.isUserLiked(currentUser.id, userId);
    } catch (e) {
      return false;
    }
  }

  /// Check if users are matched
  Future<bool> isMatched(String userId) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        return false;
      }

      // Check if match exists and is accepted
      return false; // Would query Firestore
    } catch (e) {
      return false;
    }
  }
}

/// Swipe controller for swipe-based matching
final swipeControllerProvider =
    NotifierProvider<SwipeController, AsyncValue<List<UserProfile>>>(() {
  return SwipeController();
});

class SwipeController extends Notifier<AsyncValue<List<UserProfile>>> {
  late final MatchService _matchService;
  final List<UserProfile> _swipeQueue = [];
  int _currentIndex = 0;

  @override
  AsyncValue<List<UserProfile>> build() {
    _matchService = ref.watch(matchServiceProvider);
    _loadSwipeQueue();
    return const AsyncValue.loading();
  }

  Future<void> _loadSwipeQueue() async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        state = const AsyncValue.data([]);
        return;
      }

      // Load potential matches
      // This would query Firestore for users matching preferences
      _swipeQueue.clear();
      _currentIndex = 0;
      state = AsyncValue.data(List.from(_swipeQueue));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Swipe right (like)
  Future<void> swipeRight() async {
    if (_currentIndex >= _swipeQueue.length) return;

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final targetUser = _swipeQueue[_currentIndex];
      await _matchService.likeUser(currentUser.id, targetUser.id);

      _currentIndex++;
      state = AsyncValue.data(List.from(_swipeQueue));

      // Load more if running low
      if (_swipeQueue.length - _currentIndex < 3) {
        await _loadMoreProfiles();
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Swipe left (pass)
  Future<void> swipeLeft() async {
    if (_currentIndex >= _swipeQueue.length) return;

    try {
      _currentIndex++;
      state = AsyncValue.data(List.from(_swipeQueue));

      // Load more if running low
      if (_swipeQueue.length - _currentIndex < 3) {
        await _loadMoreProfiles();
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Super like
  Future<void> superLike() async {
    if (_currentIndex >= _swipeQueue.length) return;

    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final targetUser = _swipeQueue[_currentIndex];
      // Would create a match with super_like flag
      await _matchService.likeUser(currentUser.id, targetUser.id);

      _currentIndex++;
      state = AsyncValue.data(List.from(_swipeQueue));
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Undo last swipe
  void undoSwipe() {
    if (_currentIndex > 0) {
      _currentIndex--;
      state = AsyncValue.data(List.from(_swipeQueue));
    }
  }

  /// Get current profile
  UserProfile? get currentProfile {
    if (_currentIndex < _swipeQueue.length) {
      return _swipeQueue[_currentIndex];
    }
    return null;
  }

  /// Reload queue
  Future<void> reload() async {
    await _loadSwipeQueue();
  }

  Future<void> _loadMoreProfiles() async {
    try {
      // Load more potential matches
      // This would append to _swipeQueue
    } catch (e) {
      // Handle error
    }
  }
}

/// Match statistics provider
final matchStatisticsProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield {};
    return;
  }

  // Calculate match statistics
  yield {
    'totalMatches': 0,
    'pendingRequests': 0,
    'acceptedMatches': 0,
    'rejectedMatches': 0,
  };
});

/// Daily swipe limit provider
final dailySwipeLimitProvider = StreamProvider<int>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield 0;
    return;
  }

  // Check subscription status and return limit
  // Free users: 50 swipes/day, Premium: unlimited
  yield 50;
});

/// Remaining swipes provider
final remainingSwipesProvider = StreamProvider<int>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield 0;
    return;
  }

  final limit = await ref.watch(dailySwipeLimitProvider.future);

  // Calculate swipes used today
  // This would query Firestore for likes created today
  const swipesUsed = 0;

  yield limit - swipesUsed;
});
