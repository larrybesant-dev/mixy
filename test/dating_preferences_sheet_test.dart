import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/speed_dating/models/dating_preferences.dart';
import 'package:mixvy/features/speed_dating/providers/dating_preferences_provider.dart';
import 'package:mixvy/features/speed_dating/widgets/dating_preferences_sheet.dart';
import 'package:mixvy/services/dating_location_service.dart';
import 'package:mixvy/services/dating_preferences_store.dart';

class _MemoryDatingPreferencesStore implements DatingPreferencesStore {
  _MemoryDatingPreferencesStore(this.current);

  DatingPreferences current;
  DatingPreferences? saved;
  bool cleared = false;
  Object? saveError;

  @override
  Future<void> clear(String userId) async {
    cleared = true;
    current = const DatingPreferences();
  }

  @override
  Future<DatingPreferences> load(String userId) async => current;

  @override
  Future<void> save(String userId, DatingPreferences preferences) async {
    final error = saveError;
    if (error != null) throw error;
    saved = preferences;
    current = preferences;
  }
}

class _FakeDatingLocationService implements DatingLocationService {
  _FakeDatingLocationService({this.coordinates, this.error});

  final DatingCoordinates? coordinates;
  final Object? error;
  int calls = 0;

  @override
  Future<DatingCoordinates?> currentCoordinates() async {
    calls++;
    final failure = error;
    if (failure != null) throw failure;
    return coordinates;
  }
}

Widget _testApp(
  _MemoryDatingPreferencesStore store,
  _FakeDatingLocationService location,
) {
  return ProviderScope(
    overrides: [
      datingPreferencesStoreProvider.overrideWithValue(store),
      datingLocationServiceProvider.overrideWithValue(location),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: DatingPreferencesSheet(userId: 'user-1'),
      ),
    ),
  );
}

Future<void> _tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows guidance when location permission is unavailable', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(const DatingPreferences());
    final location = _FakeDatingLocationService();
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Use my location');

    expect(location.calls, 1);
    expect(
      find.text(
        'Location unavailable. Allow location access in your browser or device settings.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('reports unexpected location failures and clears busy state', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(const DatingPreferences());
    final location =
        _FakeDatingLocationService(error: StateError('GPS failed'));
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Use my location');

    expect(
        find.text('Could not read your location. Try again.'), findsOneWidget);
    expect(find.text('Use my location'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('adds a successfully resolved approximate location', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(const DatingPreferences());
    final location = _FakeDatingLocationService(
      coordinates: const DatingCoordinates(
        latitude: 40.71,
        longitude: -74.01,
      ),
    );
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Use my location');

    expect(find.text('Location added. Save to apply it.'), findsOneWidget);
    expect(find.text('Remove location'), findsOneWidget);
  });

  testWidgets('requires location before saving a distance filter', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(const DatingPreferences());
    final location = _FakeDatingLocationService();
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Within 10 km');
    await _tapText(tester, 'Save');

    expect(store.saved, isNull);
    expect(location.calls, 1);
    expect(
      find.text(
        'A distance filter needs your location. Allow location access or choose "Any distance".',
      ),
      findsOneWidget,
    );
  });

  testWidgets('saves any-distance preferences without requesting location', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(const DatingPreferences());
    final location = _FakeDatingLocationService();
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Save');

    expect(location.calls, 0);
    expect(store.saved?.maxDistanceKm, isNull);
    expect(store.saved?.coordinates, isNull);
  });

  testWidgets('removing location also disables the distance filter', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(
      const DatingPreferences(
        maxDistanceKm: 25,
        coordinates: DatingCoordinates(latitude: 40.71, longitude: -74.01),
      ),
    );
    final location = _FakeDatingLocationService();
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Remove location');
    await _tapText(tester, 'Save');

    expect(store.saved?.maxDistanceKm, isNull);
    expect(store.saved?.coordinates, isNull);
    expect(location.calls, 0);
  });

  testWidgets('deletes private dating preferences after confirmation', (
    tester,
  ) async {
    final store = _MemoryDatingPreferencesStore(
      const DatingPreferences(race: 'Asian'),
    );
    final location = _FakeDatingLocationService();
    await tester.pumpWidget(_testApp(store, location));
    await tester.pumpAndSettle();

    await _tapText(tester, 'Delete preferences');
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(store.cleared, isTrue);
  });
}
