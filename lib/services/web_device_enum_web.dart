// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use, avoid_dynamic_calls
import 'dart:html' as html;

class MediaDeviceInfo {
  final String deviceId;
  final String label;
  final String kind; // 'audioinput' | 'videoinput'
  const MediaDeviceInfo({
    required this.deviceId,
    required this.label,
    required this.kind,
  });
}

Future<List<MediaDeviceInfo>> enumerateMediaDevices() async {
  final devices = html.window.navigator.mediaDevices;
  if (devices == null) return const [];
  try {
    // Request permission first so labels are populated.
    html.MediaStream? stream;
    try {
      stream = await devices.getUserMedia({'audio': true, 'video': true});
    } catch (_) {
      // Permission denied or not available — proceed anyway; labels may be empty.
    }
    if (stream != null) {
      for (final track in stream.getTracks()) {
        track.stop();
      }
    }
    final raw = await devices.enumerateDevices();
    return raw
        .where((d) => d.kind == 'audioinput' || d.kind == 'videoinput')
        .map(
          (d) => MediaDeviceInfo(
            deviceId: d.deviceId ?? '',
            label: (d.label?.isNotEmpty == true) ? d.label! : d.deviceId ?? '',
            kind: d.kind ?? '',
          ),
        )
        .toList(growable: false);
  } catch (_) {
    return const [];
  }
}
