// Automatic fallback stub for non-web platforms to prevent compilation crashes
import 'dart:async';

// We define a lightweight proxy class so the panel compiles everywhere without importing 'dart:html' on mobile
class MediaDeviceInfo {
  final String deviceId;
  final String label;
  final String kind;
  MediaDeviceInfo({required this.deviceId, required this.label, required this.kind});
}

Future<List<MediaDeviceInfo>> enumerateWebDevices() async {
  return [];
}



