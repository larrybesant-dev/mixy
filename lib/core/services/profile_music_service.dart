// lib/core/services/profile_music_service.dart
//
// ProfileMusicService – plays (and stops) a user's favourite track
// preview when their profile is opened.
//
// Plays once per profile view at low volume.
// Auto-stopped on navigation or when another profile is opened.
// ─────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'music_settings_service.dart';

// ─────────────────────────────────────────────────────────────────
// State model
// ─────────────────────────────────────────────────────────────────
class ProfileMusicState {
  final bool isPlaying;
  final String? currentUrl;

  const ProfileMusicState({this.isPlaying = false, this.currentUrl});

  ProfileMusicState copyWith({bool? isPlaying, String? currentUrl}) =>
      ProfileMusicState(
        isPlaying: isPlaying ?? this.isPlaying,
        currentUrl: currentUrl,
      );
}

// ─────────────────────────────────────────────────────────────────
// Notifier (Riverpod 3 compatible)
// ─────────────────────────────────────────────────────────────────
class ProfileMusicNotifier extends Notifier<ProfileMusicState> {
  final _player = AudioPlayer();
  static const double _previewVolume = 0.22;
  static const Duration _maxPlayDuration = Duration(seconds: 20);
  Timer? _stopTimer;

  @override
  ProfileMusicState build() => const ProfileMusicState();

  // ── Public API ─────────────────────────────────────────────────

  /// Call when a profile screen opens.
  Future<void> playPreview(String? previewUrl) async {
    final settingsAsync = ref.read(musicSettingsProvider);
    final canPlay = settingsAsync.whenOrNull(
          data: (svc) => svc.canPlay(AudioFeature.profile),
        ) ??
        false;
    if (!canPlay) return;
    if (previewUrl == null || previewUrl.isEmpty) return;

    // If same track already playing, do nothing.
    if (state.isPlaying && state.currentUrl == previewUrl) return;

    await stop();

    try {
      await _player.setVolume(_previewVolume);
      await _player.play(UrlSource(previewUrl));
      state = ProfileMusicState(isPlaying: true, currentUrl: previewUrl);

      _stopTimer = Timer(_maxPlayDuration, stop);
      _player.onPlayerComplete.listen((_) {
        _stopTimer?.cancel();
        state = const ProfileMusicState();
      });
    } catch (e) {
      debugPrint('[ProfileMusic] Could not play $previewUrl: $e');
      state = const ProfileMusicState();
    }
  }

  /// Call when the profile screen is popped / disposed.
  Future<void> stop() async {
    _stopTimer?.cancel();
    try {
      await _player.stop();
    } catch (_) {}
    state = const ProfileMusicState();
  }

  // ── Visualizer helper: expose playback position (0.0–1.0) ─────
  Stream<double> get progressStream {
    return _player.onPositionChanged.asyncMap((pos) async {
      final dur = await _player.getDuration();
      if (dur == null || dur.inMilliseconds == 0) return 0.0;
      return (pos.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
    });
  }
}

// ── Riverpod provider ─────────────────────────────────────────────
final profileMusicProvider =
    NotifierProvider<ProfileMusicNotifier, ProfileMusicState>(
  ProfileMusicNotifier.new,
);
