import '../features/speed_dating/models/dating_preferences.dart';

abstract class DatingLocationService {
  /// Returns approximate coordinates, or null when permission is denied or
  /// the location cannot be read.
  Future<DatingCoordinates?> currentCoordinates();
}
