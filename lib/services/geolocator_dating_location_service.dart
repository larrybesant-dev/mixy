import 'package:geolocator/geolocator.dart';

import '../features/speed_dating/models/dating_preferences.dart';
import 'dating_location_service.dart';

class GeolocatorDatingLocationService implements DatingLocationService {
  @override
  Future<DatingCoordinates?> currentCoordinates() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 15),
      ),
    );
    if (!position.latitude.isFinite || !position.longitude.isFinite) {
      return null;
    }
    // Two decimals is roughly 1 km, which is enough for distance filters
    // and avoids storing a precise location.
    return DatingCoordinates(
      latitude: _roundTo2(position.latitude),
      longitude: _roundTo2(position.longitude),
    );
  }

  double _roundTo2(double value) => (value * 100).roundToDouble() / 100;
}
