import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/speed_dating/models/dating_preferences.dart';

void main() {
  group('DatingPreferences', () {
    test('defaults to any age, any sex, and any distance', () {
      final prefs = DatingPreferences.fromFirestore(null);
      expect(prefs.lookingFor, isEmpty);
      expect(prefs.minAge, 18);
      expect(prefs.maxAge, 99);
      expect(prefs.maxDistanceKm, isNull);
      expect(prefs.coordinates, isNull);
    });

    test('round-trips a full set of preferences', () {
      const original = DatingPreferences(
        lookingFor: ['Woman', 'Non-binary'],
        minAge: 25,
        maxAge: 34,
        maxDistanceKm: 40.23,
        distanceUnit: 'mi',
        race: 'Asian',
        sexuality: 'Bisexual',
        preferredRaces: ['Black', 'White'],
        preferredSexualities: ['Queer'],
        coordinates: DatingCoordinates(latitude: 40.71, longitude: -74.01),
      );
      final restored = DatingPreferences.fromFirestore(original.toFirestore());
      expect(restored.lookingFor, ['Woman', 'Non-binary']);
      expect(restored.minAge, 25);
      expect(restored.maxAge, 34);
      expect(restored.maxDistanceKm, 40.23);
      expect(restored.distanceUnit, 'mi');
      expect(restored.race, 'Asian');
      expect(restored.sexuality, 'Bisexual');
      expect(restored.preferredRaces, ['Black', 'White']);
      expect(restored.preferredSexualities, ['Queer']);
      expect(restored.coordinates?.latitude, 40.71);
      expect(restored.coordinates?.longitude, -74.01);
    });

    test('drops unknown gender, race, and sexuality values', () {
      final prefs = DatingPreferences.fromFirestore({
        'lookingFor': ['Woman', 'Robot'],
        'race': 'Martian',
        'sexuality': 'Other',
        'preferredRaces': ['Nope', 'Asian'],
        'preferredSexualities': 42,
      });
      expect(prefs.lookingFor, ['Woman']);
      expect(prefs.race, isNull);
      expect(prefs.sexuality, 'Other');
      expect(prefs.preferredRaces, ['Asian']);
      expect(prefs.preferredSexualities, isEmpty);
    });

    test('clamps ages and keeps maxAge at or above minAge', () {
      final prefs = DatingPreferences.fromFirestore({
        'minAge': 5,
        'maxAge': 200,
      });
      expect(prefs.minAge, 18);
      expect(prefs.maxAge, 99);

      final inverted = DatingPreferences.fromFirestore({
        'minAge': 40,
        'maxAge': 30,
      });
      expect(inverted.minAge, 40);
      expect(inverted.maxAge, 40);
    });

    test('rejects distances outside 1–500 km and rounds to 2 decimals', () {
      expect(
        DatingPreferences.fromFirestore({'maxDistanceKm': 0}).maxDistanceKm,
        isNull,
      );
      expect(
        DatingPreferences.fromFirestore({'maxDistanceKm': 501}).maxDistanceKm,
        isNull,
      );
      expect(
        DatingPreferences.fromFirestore({'maxDistanceKm': 'far'}).maxDistanceKm,
        isNull,
      );
      expect(
        DatingPreferences.fromFirestore({'maxDistanceKm': 7}).maxDistanceKm,
        7,
      );
      expect(
        DatingPreferences.fromFirestore({'maxDistanceKm': 7.456}).maxDistanceKm,
        7.46,
      );
    });

    test('falls back to km for unknown distance units', () {
      expect(
        DatingPreferences.fromFirestore({'distanceUnit': 'furlong'})
            .distanceUnit,
        'km',
      );
      expect(
        DatingPreferences.fromFirestore({'distanceUnit': 'mi'}).distanceUnit,
        'mi',
      );
    });

    test('converts miles presets to canonical km and back', () {
      expect(datingDistanceToKm(10, 'mi'), 16.09);
      expect(datingDistanceToKm(100, 'mi'), 160.93);
      expect(datingDistanceToKm(25, 'km'), 25);
      expect(datingDistanceFromKm(160.93, 'mi'), 100);
      expect(datingDistanceFromKm(50, 'km'), 50);
    });

    test('ignores invalid coordinates', () {
      expect(
        DatingPreferences.fromFirestore({
          'latitude': 120,
          'longitude': 10,
        }).coordinates,
        isNull,
      );
      expect(
        DatingPreferences.fromFirestore({
          'latitude': 10,
          'longitude': null,
        }).coordinates,
        isNull,
      );
    });
  });
}
