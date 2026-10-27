import '../features/speed_dating/models/dating_preferences.dart';

abstract class DatingPreferencesStore {
  Future<DatingPreferences> load(String userId);

  Future<void> save(String userId, DatingPreferences preferences);

  Future<void> clear(String userId);
}
