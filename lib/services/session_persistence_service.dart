import 'package:shared_preferences/shared_preferences.dart';

class SessionPersistence {
  static const String _kLastRoomId = 'mixvy.last_room_id';
  static const String _kFeedScrollOffset = 'mixvy.feed_scroll_offset';
  static const String _kIsSpeedDatingActive = 'mixvy.speed_dating_active';

  static Future<void> saveLastRoom(String? roomId) async {
    final prefs = await SharedPreferences.getInstance();
    if (roomId == null) {
      await prefs.remove(_kLastRoomId);
    } else {
      await prefs.setString(_kLastRoomId, roomId);
    }
  }

  static Future<String?> getLastRoom() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kLastRoomId);
  }

  static Future<void> saveFeedScroll(double offset) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFeedScrollOffset, offset);
  }

  static Future<double> getFeedScroll() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_kFeedScrollOffset) ?? 0.0;
  }

  static Future<void> setSpeedDatingActive(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kIsSpeedDatingActive, active);
  }

  static Future<bool> isSpeedDatingActive() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kIsSpeedDatingActive) ?? false;
  }
}
