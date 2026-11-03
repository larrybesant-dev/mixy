import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/firebase_providers.dart';
import '../../../services/dating_location_service.dart';
import '../../../services/dating_preferences_store.dart';
import '../../../services/firestore_dating_preferences_store.dart';
import '../../../services/geolocator_dating_location_service.dart';
import '../models/dating_preferences.dart';

final datingPreferencesStoreProvider = Provider<DatingPreferencesStore>(
  (ref) => FirestoreDatingPreferencesStore(ref.watch(firestoreProvider)),
);

final datingLocationServiceProvider = Provider<DatingLocationService>(
  (ref) => GeolocatorDatingLocationService(),
);

final datingPreferencesProvider =
    FutureProvider.autoDispose.family<DatingPreferences, String>(
  (ref, userId) => ref.watch(datingPreferencesStoreProvider).load(userId),
);
