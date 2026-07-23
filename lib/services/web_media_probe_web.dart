// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:async';

Future<void> ensureUserMediaAccess({
  required bool video,
  required bool audio,
}) async {
  if (html.window.isSecureContext != true) {
    throw StateError('Camera/microphone requires a secure context (HTTPS or localhost).');
  }

  final devices = html.window.navigator.mediaDevices;
  if (devices == null) {
    throw StateError('Media devices are not available in this browser.');
  }

  try {
    // Force a 5-second timeout so the hardware layer cannot hang the Flutter app microtask queue
    final stream = await devices.getUserMedia(<String, dynamic>{
      'video': video,
      'audio': audio,
    }).timeout(const Duration(seconds: 5), onTimeout: () {
      throw TimeoutException('Browser hardware request timed out. Ensure the permission popup is not blocked.');
    });

    // Clean up tracks immediately after verifying access
    for (final track in stream.getTracks()) {
      track.stop();
    }
  } on TimeoutException {
    // Timeout during media probe
    rethrow;
  } catch (e) {
    // Error capturing media devices
    rethrow;
  }
}



