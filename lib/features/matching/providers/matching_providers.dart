import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/matching_profile.dart';
import '../models/match_score.dart';
import '../models/match_model.dart';
import '../services/match_service.dart';
import '../services/matching_service.dart';
import 'package:mixmingle/shared/providers/providers.dart';

/// Provider for MatchService (new match algorithm)
final matchServiceProvider = Provider<MatchService>((ref) {
  return MatchService(
    FirebaseFirestore.instance,
    FirebaseFunctions.instance,
  );
});

/// Provider for generated matches (new algorithm)
final generatedMatchesProvider =
    StreamProvider.autoDispose<List<MatchModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return const Stream.empty();
  }

  final service = ref.watch(matchServiceProvider);
  return service.watchGeneratedMatches(user.uid);
});

/// Provider for mutual matches
final mutualMatchesProvider =
    StreamProvider.autoDispose<List<MatchHistoryModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return const Stream.empty();
  }

  final service = ref.watch(matchServiceProvider);
  return service.watchMutualMatches(user.uid);
});

/// Provider for match history
final matchHistoryProvider =
    StreamProvider.autoDispose<List<MatchHistoryModel>>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.value;

  if (user == null) {
    return const Stream.empty();
  }

  final service = ref.watch(matchServiceProvider);
  return service.watchMatchHistory(user.uid);
});

/// Provider for MatchingService instance (legacy)
final matchingServiceProvider = Provider<MatchingService>((ref) {
  return MatchingService(firestore: FirebaseFirestore.instance);
});

/// Provider for current user's matching profile
final currentMatchingProfileProvider =
    FutureProvider<MatchingProfile?>((ref) async {
  final currentUser = await ref.watch(currentUserProvider.future);
  if (currentUser == null) return null;

  final doc = await FirebaseFirestore.instance
      .collection('matching_profiles')
      .doc(currentUser.id)
      .get();

  if (!doc.exists) return null;

  return MatchingProfile.fromJson(doc.data()!);
});

/// Provider for fetching matches for current user
final matchesProvider = FutureProvider.family<List<RankedMatch>, MatchesFilter>(
  (ref, filter) async {
    final profile = await ref.watch(currentMatchingProfileProvider.future);
    if (profile == null) return [];

    final matchingService = ref.watch(matchingServiceProvider);
    return matchingService.findMatches(
      profile,
      limit: filter.limit,
      minScore: filter.minScore,
    );
  },
);

/// Provider for match statistics
final matchStatisticsProvider = FutureProvider<MatchStatistics?>((ref) async {
  final profile = await ref.watch(currentMatchingProfileProvider.future);
  if (profile == null) return null;

  final matchingService = ref.watch(matchingServiceProvider);
  return matchingService.calculateStatistics(profile);
});

/// Provider for calculating match score with specific user
final matchScoreProvider =
    FutureProvider.family<MatchScore?, String>((ref, targetUserId) async {
  final currentProfile = await ref.watch(currentMatchingProfileProvider.future);
  if (currentProfile == null) return null;

  final targetDoc = await FirebaseFirestore.instance
      .collection('matching_profiles')
      .doc(targetUserId)
      .get();

  if (!targetDoc.exists) return null;

  final targetProfile = MatchingProfile.fromJson(targetDoc.data()!);
  final matchingService = ref.watch(matchingServiceProvider);

  return matchingService.calculateMatchScore(currentProfile, targetProfile);
});

/// Notifier for match filter settings
class MatchFilterNotifier extends Notifier<MatchesFilter> {
  @override
  MatchesFilter build() {
    return const MatchesFilter(
      limit: 50,
      minScore: 50.0,
      maxDistance: 25.0,
    );
  }

  void updateFilter(MatchesFilter filter) {
    state = filter;
  }
}

/// State provider for match filter settings
final matchFilterProvider =
    NotifierProvider<MatchFilterNotifier, MatchesFilter>(
  () => MatchFilterNotifier(),
);

/// Provider for top matches (convenience provider)
final topMatchesProvider = FutureProvider<List<RankedMatch>>((ref) async {
  final filter = ref.watch(matchFilterProvider);
  return ref.watch(matchesProvider(filter).future);
});

/// Stream provider for real-time match updates
final matchesStreamProvider = StreamProvider<List<RankedMatch>>((ref) async* {
  final profile = await ref.watch(currentMatchingProfileProvider.future);
  if (profile == null) {
    yield [];
    return;
  }

  final matchingService = ref.watch(matchingServiceProvider);
  final filter = ref.watch(matchFilterProvider);

  // Initial load
  yield await matchingService.findMatches(
    profile,
    limit: filter.limit,
    minScore: filter.minScore,
  );

  // Listen for profile changes and recalculate
  await for (final _ in FirebaseFirestore.instance
      .collection('matching_profiles')
      .where('isActive', isEqualTo: true)
      .snapshots()) {
    yield await matchingService.findMatches(
      profile,
      limit: filter.limit,
      minScore: filter.minScore,
    );
  }
});

/// Provider for user's liked matches
final likedMatchesProvider = FutureProvider<List<RankedMatch>>((ref) async {
  final profile = await ref.watch(currentMatchingProfileProvider.future);
  if (profile == null) return [];

  final matchingService = ref.watch(matchingServiceProvider);
  final allMatches = await matchingService.findMatches(profile, limit: 100);

  return allMatches.where((match) => profile.hasLiked(match.userId)).toList();
});

/// Provider for mutual matches (ranked)
final rankedMutualMatchesProvider =
    FutureProvider<List<RankedMatch>>((ref) async {
  final profile = await ref.watch(currentMatchingProfileProvider.future);
  if (profile == null) return [];

  final matchingService = ref.watch(matchingServiceProvider);
  final allMatches = await matchingService.findMatches(profile, limit: 100);

  final mutualMatches = <RankedMatch>[];

  for (final match in allMatches) {
    // Check if they also liked us
    final theirDoc = await FirebaseFirestore.instance
        .collection('matching_profiles')
        .doc(match.userId)
        .get();

    if (theirDoc.exists) {
      final theirProfile = MatchingProfile.fromJson(theirDoc.data()!);
      if (theirProfile.hasLiked(profile.userId)) {
        mutualMatches.add(match);
      }
    }
  }

  return mutualMatches;
});

/// Filter configuration for matches
class MatchesFilter {
  final int limit;
  final double minScore;
  final double maxDistance;

  const MatchesFilter({
    required this.limit,
    required this.minScore,
    required this.maxDistance,
  });

  MatchesFilter copyWith({
    int? limit,
    double? minScore,
    double? maxDistance,
  }) {
    return MatchesFilter(
      limit: limit ?? this.limit,
      minScore: minScore ?? this.minScore,
      maxDistance: maxDistance ?? this.maxDistance,
    );
  }
}
