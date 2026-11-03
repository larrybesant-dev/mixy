import 'package:flutter/foundation.dart';

const List<String> datingGenderOptions = ['Woman', 'Man', 'Non-binary'];

const List<String> datingRaceOptions = [
  'Asian',
  'Black',
  'Hispanic/Latino',
  'Middle Eastern',
  'Mixed',
  'South Asian',
  'White',
  'Other',
];

const List<String> datingSexualityOptions = [
  'Straight',
  'Gay',
  'Lesbian',
  'Bisexual',
  'Pansexual',
  'Queer',
  'Asexual',
  'Other',
];

const String datingUnitKm = 'km';
const String datingUnitMi = 'mi';
const List<String> datingDistanceUnits = [datingUnitKm, datingUnitMi];

/// Preset distances shown as chips, in the viewer's chosen unit.
const List<int> datingDistancePresets = [10, 25, 50, 100];
const double datingMinDistanceKm = 1;
const double datingMaxDistanceKm = 500;
const double _kmPerMile = 1.609344;
const int datingMinAge = 18;
const int datingMaxAge = 99;

/// Converts a distance in [unit] to the canonical km value stored in Firestore.
double datingDistanceToKm(num value, String unit) {
  final km = unit == datingUnitMi ? value * _kmPerMile : value.toDouble();
  return double.parse(km.toStringAsFixed(2));
}

/// Converts a stored km value into [unit] for display.
double datingDistanceFromKm(double km, String unit) {
  final value = unit == datingUnitMi ? km / _kmPerMile : km;
  return double.parse(value.toStringAsFixed(2));
}

@immutable
class DatingCoordinates {
  const DatingCoordinates({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// Dating filters for the current user. Empty lists and null values mean "any".
@immutable
class DatingPreferences {
  const DatingPreferences({
    this.lookingFor = const [],
    this.minAge = datingMinAge,
    this.maxAge = datingMaxAge,
    this.maxDistanceKm,
    this.distanceUnit = datingUnitKm,
    this.race,
    this.sexuality,
    this.preferredRaces = const [],
    this.preferredSexualities = const [],
    this.coordinates,
  });

  final List<String> lookingFor;
  final int minAge;
  final int maxAge;

  /// Canonical distance limit in km. Null means any distance.
  final double? maxDistanceKm;

  /// Unit the viewer chose for display and preset chips. Storage is always km.
  final String distanceUnit;

  /// Private: used only for matching, never shown to other users.
  final String? race;

  /// Private: used only for matching, never shown to other users.
  final String? sexuality;

  final List<String> preferredRaces;
  final List<String> preferredSexualities;
  final DatingCoordinates? coordinates;

  Map<String, dynamic> toFirestore() {
    return {
      'lookingFor': lookingFor,
      'minAge': minAge,
      'maxAge': maxAge,
      'maxDistanceKm': maxDistanceKm,
      'distanceUnit': distanceUnit,
      'race': race,
      'sexuality': sexuality,
      'preferredRaces': preferredRaces,
      'preferredSexualities': preferredSexualities,
      'latitude': coordinates?.latitude,
      'longitude': coordinates?.longitude,
    };
  }

  factory DatingPreferences.fromFirestore(Map<String, dynamic>? data) {
    final source = data ?? const <String, dynamic>{};
    final minAge = _clampAge(source['minAge'], datingMinAge);
    final maxAge = _clampAge(source['maxAge'], datingMaxAge);
    return DatingPreferences(
      lookingFor: _filterOptions(source['lookingFor'], datingGenderOptions),
      minAge: minAge,
      maxAge: maxAge < minAge ? minAge : maxAge,
      maxDistanceKm: _pickDistance(source['maxDistanceKm']),
      distanceUnit: _pickUnit(source['distanceUnit']),
      race: _pickOption(source['race'], datingRaceOptions),
      sexuality: _pickOption(source['sexuality'], datingSexualityOptions),
      preferredRaces: _filterOptions(
        source['preferredRaces'],
        datingRaceOptions,
      ),
      preferredSexualities: _filterOptions(
        source['preferredSexualities'],
        datingSexualityOptions,
      ),
      coordinates: _pickCoordinates(source['latitude'], source['longitude']),
    );
  }

  static int _clampAge(dynamic value, int fallback) {
    if (value is! num || !value.isFinite) return fallback;
    return value.round().clamp(datingMinAge, datingMaxAge);
  }

  static List<String> _filterOptions(dynamic value, List<String> allowed) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .where((item) => allowed.contains(item))
        .toList(growable: false);
  }

  static String? _pickOption(dynamic value, List<String> allowed) {
    return value is String && allowed.contains(value) ? value : null;
  }

  static double? _pickDistance(dynamic value) {
    if (value is! num || !value.isFinite) return null;
    if (value < datingMinDistanceKm || value > datingMaxDistanceKm) return null;
    return double.parse(value.toStringAsFixed(2)).toDouble();
  }

  static String _pickUnit(dynamic value) {
    return value is String && datingDistanceUnits.contains(value)
        ? value
        : datingUnitKm;
  }

  static DatingCoordinates? _pickCoordinates(dynamic lat, dynamic lng) {
    if (lat is! num || lng is! num) return null;
    if (!lat.isFinite || !lng.isFinite) return null;
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) return null;
    return DatingCoordinates(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
  }
}
