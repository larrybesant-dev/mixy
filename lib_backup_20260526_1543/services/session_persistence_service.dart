import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class SessionPersistence {
  static const String _kLastRoomId = 'mixvy.last_room_id';
  static const String _kFeedScrollOffset = 'mixvy.feed_scroll_offset';
  static const String _kIsSpeedDatingActive = 'mixvy.speed_dating_active';
  static final Map<String, Object?> _fallbackStore = <String, Object?>{};

  static Future<SharedPreferences?> _prefsOrNull() async {
    try {
      return await SharedPreferences.getInstance();
    } on MissingPluginException {
      // Tests/non-plugin hosts can execute this path without shared_preferences.
      return null;
    }
  }

  static Future<void> saveLastRoom(String? roomId) async {
    final prefs = await _prefsOrNull();
    if (prefs == null) {
      _fallbackStore[_kLastRoomId] = roomId;
      return;
    }
    if (roomId == null) {
      await prefs.remove(_kLastRoomId);
    } else {
      await prefs.setString(_kLastRoomId, roomId);
    }
  }

  static Future<String?> getLastRoom() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) {
      final value = _fallbackStore[_kLastRoomId];
      return value is String ? value : null;
    }
    return prefs.getString(_kLastRoomId);
  }

  static Future<void> saveFeedScroll(double offset) async {
    final prefs = await _prefsOrNull();
    if (prefs == null) {
      _fallbackStore[_kFeedScrollOffset] = offset;
      return;
    }
    await prefs.setDouble(_kFeedScrollOffset, offset);
  }

  static Future<double> getFeedScroll() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) {
      final value = _fallbackStore[_kFeedScrollOffset];
      return value is double ? value : 0.0;
    }
    return prefs.getDouble(_kFeedScrollOffset) ?? 0.0;
  }

  static Future<void> setSpeedDatingActive(bool active) async {
    final prefs = await _prefsOrNull();
    if (prefs == null) {
      _fallbackStore[_kIsSpeedDatingActive] = active;
      return;
    }
    await prefs.setBool(_kIsSpeedDatingActive, active);
  }

  static Future<bool> isSpeedDatingActive() async {
    final prefs = await _prefsOrNull();
    if (prefs == null) {
      final value = _fallbackStore[_kIsSpeedDatingActive];
      return value is bool ? value : false;
    }
    return prefs.getBool(_kIsSpeedDatingActive) ?? false;
  }
}
