import 'package:flutter/foundation.dart';
import 'dart:math';

// Conditional imports for geolocator (not available on all platforms)
import 'package:geolocator/geolocator.dart' as geo;

/// Location data model
class LocationData {
  final double latitude;
  final double longitude;
  final double? accuracy;
  final double? altitude;
  final double? heading;
  final double? speed;
  final DateTime timestamp;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.altitude,
    this.heading,
    this.speed,
    required this.timestamp,
  });

  /// Convert to Firestore GeoPoint-compatible map
  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'altitude': altitude,
        'heading': heading,
        'speed': speed,
        'timestamp': timestamp.toIso8601String(),
      };

  factory LocationData.fromMap(Map<String, dynamic> map) => LocationData(
        latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
        longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
        accuracy: (map['accuracy'] as num?)?.toDouble(),
        altitude: (map['altitude'] as num?)?.toDouble(),
        heading: (map['heading'] as num?)?.toDouble(),
        speed: (map['speed'] as num?)?.toDouble(),
        timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Service for location-based features
class LocationService {
  LocationService._();
  static final LocationService _instance = LocationService._();

  factory LocationService() => _instance;

  static LocationService get instance => _instance;

  /// Request location permissions and return status
  Future<bool> requestLocationPermission() async {
    try {
      // Skip on web (no real location access)
      if (kIsWeb) {
        debugPrint('[LocationService] Location not available on web');
        return false;
      }

      final permission = await geo.Geolocator.checkPermission();

      if (permission == geo.LocationPermission.denied) {
        final result = await geo.Geolocator.requestPermission();
        return result == geo.LocationPermission.whileInUse || result == geo.LocationPermission.always;
      }

      if (permission == geo.LocationPermission.deniedForever) {
        debugPrint('[LocationService] Location permission denied forever. Open app settings.');
        await geo.Geolocator.openLocationSettings();
        return false;
      }

      return permission == geo.LocationPermission.whileInUse || permission == geo.LocationPermission.always;
    } catch (e) {
      debugPrint('[LocationService] Permission error: $e');
      return false;
    }
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    if (kIsWeb) return false;
    try {
      return await geo.Geolocator.isLocationServiceEnabled();
    } catch (e) {
      debugPrint('[LocationService] Error checking service status: $e');
      return false;
    }
  }

  /// Get current user location
  Future<LocationData?> getCurrentLocation() async {
    try {
      // Check if service is enabled
      final serviceEnabled = await isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('[LocationService] Location service disabled');
        return null;
      }

      // Request permission
      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('[LocationService] No location permission');
        return null;
      }

      // Get position with timeout
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.best,
        timeLimit: const Duration(seconds: 10),
      );

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestamp: DateTime.fromMillisecondsSinceEpoch(position.timestamp?.millisecondsSinceEpoch ?? 0),
      );
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      return null;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistance({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    // Using Haversine formula
    const earthRadiusKm = 6371.0;

    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) * sin(dLng / 2) * sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  /// Calculate distance in miles
  static double calculateDistanceMiles({
    required double lat1,
    required double lng1,
    required double lat2,
    required double lng2,
  }) {
    return calculateDistance(lat1: lat1, lng1: lng1, lat2: lat2, lng2: lng2) * 0.621371;
  }

  /// Convert degrees to radians
  static double _toRadians(double degrees) => degrees * pi / 180.0;

  /// Stream user's current location (real-time updates)
  Stream<LocationData> streamCurrentLocation({
    geo.LocationAccuracy desiredAccuracy = geo.LocationAccuracy.best,
    int distanceFilter = 10, // meters
  }) async* {
    try {
      if (kIsWeb) {
        debugPrint('[LocationService] Location streaming not available on web');
        return;
      }

      final hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('[LocationService] No permission for location stream');
        return;
      }

      // Listen to position updates
      await for (final position in geo.Geolocator.getPositionStream(
        desiredAccuracy: desiredAccuracy,
        distanceFilter: distanceFilter,
      )) {
        yield LocationData(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          altitude: position.altitude,
          heading: position.heading,
          speed: position.speed,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            position.timestamp?.millisecondsSinceEpoch ?? 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('[LocationService] Stream error: $e');
    }
  }

  /// Get last known location (faster than getCurrentLocation)
  Future<LocationData?> getLastKnownLocation() async {
    try {
      if (kIsWeb) return null;

      final position = await geo.Geolocator.getLastKnownPosition();
      if (position == null) return null;

      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        heading: position.heading,
        speed: position.speed,
        timestamp: DateTime.fromMillisecondsSinceEpoch(
          position.timestamp?.millisecondsSinceEpoch ?? 0,
        ),
      );
    } catch (e) {
      debugPrint('[LocationService] Error getting last known location: $e');
      return null;
    }
  }

  /// Filter events by radius from a center location
  static List<T> filterEventsByRadius<T>({
    required List<T> events,
    required double centerLat,
    required double centerLng,
    required double radiusKm,
    required double Function(T) getLat,
    required double Function(T) getLng,
  }) {
    return events
        .where((event) {
          final distance = calculateDistance(
            lat1: centerLat,
            lng1: centerLng,
            lat2: getLat(event),
            lng2: getLng(event),
          );
          return distance <= radiusKm;
        })
        .toList(growable: false);
  }

  /// Sort events by distance from a center location
  static List<T> sortEventsByDistance<T>({
    required List<T> events,
    required double centerLat,
    required double centerLng,
    required double Function(T) getLat,
    required double Function(T) getLng,
  }) {
    final sorted = [...events];
    sorted.sort((a, b) {
      final distA = calculateDistance(
        lat1: centerLat,
        lng1: centerLng,
        lat2: getLat(a),
        lng2: getLng(a),
      );
      final distB = calculateDistance(
        lat1: centerLat,
        lng1: centerLng,
        lat2: getLat(b),
        lng2: getLng(b),
      );
      return distA.compareTo(distB);
    });
    return sorted;
  }
}
