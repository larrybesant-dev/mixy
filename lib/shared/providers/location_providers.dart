import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../services/location/location_service.dart';
import '../../models/event_model_with_location.dart';
import '../../models/user_model.dart';

// ── Service Provider ────────────────────────────────────────────────────

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService.instance;
});

// ── Current Location (Real-time) ────────────────────────────────────────

/// Stream of user's current location updates (real-time)
final currentLocationProvider = StreamProvider<LocationData>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.streamCurrentLocation();
});

/// Get current location as a one-time Future
final currentLocationOnceProvider = FutureProvider<LocationData?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getCurrentLocation();
});

/// Get last known location (faster)
final lastKnownLocationProvider = FutureProvider<LocationData?>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.getLastKnownLocation();
});

// ── Location Permissions ────────────────────────────────────────────────

/// Check location service enabled
final locationServiceEnabledProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.isLocationServiceEnabled();
});

/// Request location permissions
final requestLocationPermissionProvider = FutureProvider<bool>((ref) async {
  final service = ref.watch(locationServiceProvider);
  return service.requestLocationPermission();
});

// ── Nearby Events (Location-Based Filtering) ────────────────────────────

/// Parameter for nearby events query
class NearbyEventsParams {
  final double radiusKm;
  final int maxResults;

  const NearbyEventsParams({
    this.radiusKm = 10.0,
    this.maxResults = 50,
  });
}

/// Firestore provider
final locationFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Get all events from Firestore collection (internal, not exported)
final _allEventsInternalProvider = FutureProvider<List<EventModel>>((ref) async {
  try {
    final firestore = ref.watch(locationFirestoreProvider);
    final snapshot = await firestore
        .collection('events')
        .orderBy('date', descending: false)
        .limit(200)
        .get();

    return snapshot.docs
        .map((doc) => EventModel.fromDoc(doc.id, doc.data()))
        .toList(growable: false);
  } catch (e) {
    debugPrintStack(label: '[LocationNearby] Error fetching events: $e');
    return [];
  }
});

/// Find nearby events within radius of user's current location
final locationNearbyEventsProvider = FutureProvider.family<List<EventModel>, NearbyEventsParams>(
  (ref, params) async {
    final currentLoc = await ref.watch(currentLocationOnceProvider.future);
    if (currentLoc == null) {
      return []; // No location data
    }

    final allEvents = await ref.watch(_allEventsInternalProvider.future);

    // Filter events by radius
    final nearby = LocationService.filterEventsByRadius(
      events: allEvents,
      centerLat: currentLoc.latitude,
      centerLng: currentLoc.longitude,
      radiusKm: params.radiusKm,
      getLat: (event) => event.latitude ?? 0.0,
      getLng: (event) => event.longitude ?? 0.0,
    );

    // Sort by distance (nearest first)
    final sorted = LocationService.sortEventsByDistance(
      events: nearby,
      centerLat: currentLoc.latitude,
      centerLng: currentLoc.longitude,
      getLat: (event) => event.latitude ?? 0.0,
      getLng: (event) => event.longitude ?? 0.0,
    );

    return sorted.take(params.maxResults).toList();
  },
);

/// Find events near a specific location (not user's current location)
final locationEventsNearPointProvider =
    FutureProvider.family<List<EventModel>, ({double latitude, double longitude, double radiusKm})>(
  (ref, params) async {
    final allEvents = await ref.watch(_allEventsInternalProvider.future);

    // Filter events by radius around specified location
    final nearby = LocationService.filterEventsByRadius(
      events: allEvents,
      centerLat: params.latitude,
      centerLng: params.longitude,
      radiusKm: params.radiusKm,
      getLat: (event) => event.latitude ?? 0.0,
      getLng: (event) => event.longitude ?? 0.0,
    );

    // Sort by distance
    return LocationService.sortEventsByDistance(
      events: nearby,
      centerLat: params.latitude,
      centerLng: params.longitude,
      getLat: (event) => event.latitude ?? 0.0,
      getLng: (event) => event.longitude ?? 0.0,
    );
  },
);

// ── Distance Calculation ────────────────────────────────────────────────

/// Calculate distance between user and a specific event
final locationDistanceToEventProvider = FutureProvider.family<double?, ({String eventId, double eventLat, double eventLng})>(
  (ref, params) async {
    final currentLoc = await ref.watch(currentLocationOnceProvider.future);
    if (currentLoc == null) return null;

    return LocationService.calculateDistance(
      lat1: currentLoc.latitude,
      lng1: currentLoc.longitude,
      lat2: params.eventLat,
      lng2: params.eventLng,
    );
  },
);

/// Calculate distance between two arbitrary locations
final locationDistanceBetweenProvider =
    Provider.family<double, ({double lat1, double lng1, double lat2, double lng2})>(
  (ref, params) {
    return LocationService.calculateDistance(
      lat1: params.lat1,
      lng1: params.lng1,
      lat2: params.lat2,
      lng2: params.lng2,
    );
  },
);

// ── Real-time Nearby Users (Location-based Matching) ────────────────────

/// Query users within radius of current location (for matching/discovery)
final locationNearbyUsersProvider = FutureProvider.family<List<UserModel>, double>(
  (ref, radiusKm) async {
    try {
      final currentLoc = await ref.watch(currentLocationOnceProvider.future);
      if (currentLoc == null) return [];

      final firestore = ref.watch(locationFirestoreProvider);
      final snapshot = await firestore
          .collection('users')
          .limit(100)
          .get();

      final users = snapshot.docs
          .map((doc) => UserModel.fromDoc(doc))
          .where((user) {
            // Filter: must have location data
            if (user.latitude == null || user.longitude == null) return false;

            // Filter: within radius
            final distance = LocationService.calculateDistance(
              lat1: currentLoc.latitude,
              lng1: currentLoc.longitude,
              lat2: user.latitude ?? 0.0,
              lng2: user.longitude ?? 0.0,
            );
            return distance <= radiusKm;
          })
          .toList(growable: true);

      // Sort by distance (nearest first)
      users.sort((a, b) {
        final distA = LocationService.calculateDistance(
          lat1: currentLoc.latitude,
          lng1: currentLoc.longitude,
          lat2: a.latitude ?? 0.0,
          lng2: a.longitude ?? 0.0,
        );
        final distB = LocationService.calculateDistance(
          lat1: currentLoc.latitude,
          lng1: currentLoc.longitude,
          lat2: b.latitude ?? 0.0,
          lng2: b.longitude ?? 0.0,
        );
        return distA.compareTo(distB);
      });

      return users;
    } catch (e) {
      debugPrintStack(label: '[LocationNearby] Error fetching nearby users: $e');
      return [];
    }
  },
);
