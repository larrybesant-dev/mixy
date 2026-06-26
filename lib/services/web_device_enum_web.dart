// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:async';

class MediaDeviceInfo {
  final String deviceId;
  final String label;
  final String kind;
  MediaDeviceInfo({required this.deviceId, required this.label, required this.kind});
}

Future<List<MediaDeviceInfo>> enumerateWebDevices() async {
  final devices = html.window.navigator.mediaDevices;
  if (devices == null) return [];

  html.MediaStream? stream;
  try {
    stream = await devices.getUserMedia({'audio': true, 'video': true}).timeout(
      const Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('Browser device enumeration timed out.'),
    );
    
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
  } finally {
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
  }
}



