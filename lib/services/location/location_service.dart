import 'package:flutter/foundation.dart';
import 'dart:math';

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
  /// On web: always returns false (location not available)
  /// On native: would use geolocator (not implemented for web build)
  Future<bool> requestLocationPermission() async {
    if (kIsWeb) {
      debugPrint('[LocationService] Location not available on web');
      return false;
    }
    // Native platform implementation would go here
    debugPrint('[LocationService] Location permissions require native implementation');
    return false;
  }

  /// Check if location services are enabled
  /// On web: always returns false
  Future<bool> isLocationServiceEnabled() async {
    if (kIsWeb) return false;
    // Native implementation would go here
    return false;
  }

  /// Get current user location
  /// On web: returns null (location not available)
  Future<LocationData?> getCurrentLocation() async {
    if (kIsWeb) {
      debugPrint('[LocationService] Location not available on web');
      return null;
    }
    // Native implementation would go here
    return null;
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
  /// On web: returns empty stream (location not available)
  Stream<LocationData> streamCurrentLocation({
    double desiredAccuracy = 0.0,
    int distanceFilter = 10, // meters
  }) async* {
    if (kIsWeb) {
      debugPrint('[LocationService] Location streaming not available on web');
      return;
    }
    // Native implementation would yield position updates
  }

  /// Get last known location (faster than getCurrentLocation)
  /// On web: returns null
  Future<LocationData?> getLastKnownLocation() async {
    if (kIsWeb) return null;
    // Native implementation would go here
    return null;
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
