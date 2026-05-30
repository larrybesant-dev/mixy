import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'webrtc_room_service_shim.dart';
import '../core/streams/stream_lifecycle_manager.dart';
import '../features/auth/controllers/auth_controller.dart';
import '../core/providers/firebase_providers.dart';

/// Pre-warms WebRTC by probing device access before a room is joined.
/// This caches permissions in the browser/OS to avoid a "permission flash"
/// or race condition during the critical room connection phase.
class MediaWarmupService {
  MediaWarmupService(this._ref);

  final Ref _ref;
  bool _warmed = false;

  Future<void> warmup() async {
    if (_warmed || !kIsWeb) return;
    _warmed = true;

    developer.log('[WebRTC] Warm-up starting...', name: 'MediaWarmup');

    try {
      // Create a temporary instance to trigger the browser's permission prompt.
      final service = WebRtcRoomService(
        firestore: _ref.read(firestoreProvider),
        localUserId: _ref.read(authControllerProvider).uid ?? 'warmup',
        streamLifecycleManager: _ref.read(streamLifecycleManagerProvider),
      );

      // Probe audio and video. This doesn't open the hardware permanently
      // because WebRTCRoomService.ensureDeviceAccess stops tracks internally.
      await service.ensureDeviceAccess(video: true, audio: true);

      developer.log('[WebRTC] Warm-up successful (permissions cached)', name: 'MediaWarmup');
    } catch (e) {
      // Warm-up failure is non-fatal; we'll just ask again during room join.
      developer.log('[WebRTC] Warm-up probe skipped or denied: $e', name: 'MediaWarmup');
    }
  }
}

final mediaWarmupProvider = Provider((ref) => MediaWarmupService(ref));


