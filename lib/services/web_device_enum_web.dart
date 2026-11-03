// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

class MediaDeviceInfo {
  final String deviceId;
  final String label;
  final String kind;
  MediaDeviceInfo(
      {required this.deviceId, required this.label, required this.kind});
}

Future<List<MediaDeviceInfo>> enumerateWebDevices() async {
  final devices = html.window.navigator.mediaDevices;
  if (devices == null) return [];

  try {
    final list = await devices.enumerateDevices();
    return list.map((d) {
      final jsDevice = d as html.MediaDeviceInfo;
      return MediaDeviceInfo(
        deviceId: jsDevice.deviceId ?? '',
        label: jsDevice.label ?? '',
        kind: jsDevice.kind ?? '',
      );
    }).toList();
  } catch (e) {
    // Device enumeration skipped or denied
    return [];
  }
}
