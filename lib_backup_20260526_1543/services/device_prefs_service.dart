import 'package:shared_preferences/shared_preferences.dart';

/// Persists preferred camera and microphone device IDs to SharedPreferences
/// so the user's selection survives page reloads.
class DevicePrefsService {
  static const _kCameraKey = 'preferred_camera_device_id';
  static const _kMicKey = 'preferred_mic_device_id';

  Future<String?> getPreferredCameraId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCameraKey);
  }

  Future<String?> getPreferredMicId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMicKey);
  }

  Future<void> setPreferredCameraId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCameraKey, deviceId);
  }

  Future<void> setPreferredMicId(String deviceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMicKey, deviceId);
  }

  Future<void> clearPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kCameraKey);
    await prefs.remove(_kMicKey);
  }
}
