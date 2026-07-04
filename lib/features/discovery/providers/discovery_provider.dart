import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/firebase_providers.dart';
import '../services/discovery_preferences_service.dart';
import '../models/discovery_preferences.dart';

// Service providers

final discoveryPreferencesServiceProvider = Provider<DiscoveryPreferencesService>((ref) {
  final firestore = ref.watch(firestoreProvider);
  return DiscoveryPreferencesService(firestore: firestore);
});

// Track which candidates have been swiped in this session
final discoverySwipedSetProvider = StateProvider<Set<String>>((ref) {
  return <String>{};
});

// Stream of user's discovery preferences
final discoveryPreferencesProvider =
    StreamProvider.family<DiscoveryPreferences, String>((ref, userId) {
  final service = ref.watch(discoveryPreferencesServiceProvider);
  return service.preferencesStream(userId);
});


// Stream of candidates available for discovery (filtered by preferences)
// TODO: Implement with actual candidate data from Firestore
// final discoveryCandidatesProvider =
//     StreamProvider.family<List<dynamic>, String>((ref, userId) async* {
//       yield [];
//     });


// Controller for managing discovery preferences
final discoveryPreferencesControllerProvider =
    StateNotifierProvider<DiscoveryPreferencesController, AsyncValue<void>>((ref) {
  final service = ref.watch(discoveryPreferencesServiceProvider);
  return DiscoveryPreferencesController(service);
});

class DiscoveryPreferencesController extends StateNotifier<AsyncValue<void>> {
  DiscoveryPreferencesController(this._service)
      : super(const AsyncValue.data(null));

  final DiscoveryPreferencesService _service;

  /// Update age range
  Future<void> updateAgeRange(String userId, int minAge, int maxAge) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateAgeRange(userId, minAge, maxAge);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Update interest tags
  Future<void> updateInterestTags(String userId, List<String> tags) async {
    state = const AsyncValue.loading();
    try {
      await _service.updateInterestTags(userId, tags);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
