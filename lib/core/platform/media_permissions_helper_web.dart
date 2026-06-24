// ignore_for_file: avoid_web_libraries_in_flutter
import 'package:web/web.dart' as web;
import 'dart:js_interop';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:mixvy/core/utils/app_logger.dart';

/// Exception thrown when media permissions are denied
class MediaPermissionException implements Exception {
  final String message;
  final Object? originalError;
  MediaPermissionException(this.message, {this.originalError});
  @override
  String toString() => 'MediaPermissionException: $message';
}

/// Web Media Permissions Helper
class MediaPermissionsHelper {
  static Future<void> ensureMediaPermissions({
    bool requireVideo = true,
    bool requireAudio = true,
  }) async {
    if (!kIsWeb) {
      AppLogger.info('Not on web, skipping media permissions check');
      return;
    }

    try {
      AppLogger.info('Requesting media permissions...');

      final mediaDevices = web.window.navigator.mediaDevices;

      final constraints = web.MediaStreamConstraints(
        audio: requireAudio.toJS,
        video: requireVideo.toJS,
      );

      final stream = await mediaDevices.getUserMedia(constraints).toDart;

      final tracks = stream.getTracks().toDart;
      for (int i = 0; i < tracks.length; i++) {
        tracks[i].stop();
      }

      AppLogger.info('Media permissions granted');
    } catch (e) {
      AppLogger.error('Media permissions denied: $e');
      throw MediaPermissionException(
        'Camera/Microphone access denied. Please allow access in your browser settings.',
        originalError: e,
      );
    }
  }

  static Future<bool> checkPermissions() async {
    if (!kIsWeb) return true;

    try {
      final permissions = web.window.navigator.permissions;

      final cameraDesc =
          <String, JSAny?>{'name': 'camera'.toJS}.jsify()! as JSObject;
      final micDesc =
          <String, JSAny?>{'name': 'microphone'.toJS}.jsify()! as JSObject;

      final cameraStatus = await permissions.query(cameraDesc).toDart;
      final micStatus = await permissions.query(micDesc).toDart;

      return cameraStatus.state == 'granted' && micStatus.state == 'granted';
    } catch (e) {
      AppLogger.warning('Could not check permissions: $e');
      return false;
    }
  }
}

