import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/agora/agora_video_service.dart';
import '../../services/storage/storage_service.dart';
import '../../services/moderation/moderation_service.dart';
import '../models/report.dart';
import '../models/block.dart';
import '../models/media_item.dart';
import 'auth_providers.dart';

/// Service providers
final agoraVideoServiceProvider = Provider<AgoraVideoService>((ref) {
  final service = AgoraVideoService(ref: ref);
  ref.onDispose(() => service.dispose());
  return service;
});

final storageServiceProvider =
    Provider<StorageService>((ref) => StorageService());

final moderationServiceProvider =
    Provider<ModerationService>((ref) => ModerationService());

/// ============================================================================
/// VIDEO/AGORA PROVIDERS
/// ============================================================================

/// Video connection state provider
final videoConnectionStateProvider =
    NotifierProvider<VideoConnectionStateNotifier, VideoConnectionState>(() {
  return VideoConnectionStateNotifier();
});

enum VideoConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  failed,
}

class VideoConnectionStateNotifier extends Notifier<VideoConnectionState> {
  @override
  VideoConnectionState build() {
    return VideoConnectionState.disconnected;
  }

  void setConnecting() {
    state = VideoConnectionState.connecting;
  }

  void setConnected() {
    state = VideoConnectionState.connected;
  }

  void setReconnecting() {
    state = VideoConnectionState.reconnecting;
  }

  void setFailed() {
    state = VideoConnectionState.failed;
  }

  void setDisconnected() {
    state = VideoConnectionState.disconnected;
  }
}

/// Video controller for Agora operations
final videoControllerProvider =
    NotifierProvider<VideoController, AsyncValue<void>>(() {
  return VideoController();
});

class VideoController extends Notifier<AsyncValue<void>> {
  late final AgoraVideoService _videoService;
  @override
  AsyncValue<void> build() {
    _videoService = ref.watch(agoraVideoServiceProvider);
    // Provider lifecycle automatically handles engine disposal via agoraVideoServiceProvider
    return const AsyncValue.data(null);
  }

  /// Note: Engine initialization is handled by AgoraVideoService provider singleton.
  /// The engine is created and initialized when the provider is first accessed.
  /// Do not call initialize() here - it could create duplicate engines.

  /// Join a channel
  Future<void> joinChannel(String channelName,
      {String? token, int? uid}) async {
    state = const AsyncValue.loading();
    try {
      ref.read(videoConnectionStateProvider.notifier).setConnecting();
      await _videoService.joinChannel(channelName, token: token, uid: uid);
      ref.read(videoConnectionStateProvider.notifier).setConnected();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      ref.read(videoConnectionStateProvider.notifier).setFailed();
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Leave channel
  Future<void> leaveChannel() async {
    try {
      await _videoService.leaveChannel();
      ref.read(videoConnectionStateProvider.notifier).setDisconnected();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Toggle microphone
  Future<void> toggleMicrophone(bool enable) async {
    try {
      await _videoService.enableLocalAudio(enable);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Toggle camera
  Future<void> toggleCamera(bool enable) async {
    try {
      await _videoService.enableLocalVideo(enable);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Switch camera
  Future<void> switchCamera() async {
    try {
      await _videoService.switchCamera();
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Mute remote user
  Future<void> muteRemoteUser(int uid, bool mute) async {
    try {
      await _videoService.muteRemoteAudioStream(uid, mute);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Note: Disposal is handled automatically by the provider lifecycle.
  /// Do not manually dispose the video service here.
}

/// Local audio enabled state
final localAudioEnabledProvider =
    NotifierProvider<LocalAudioEnabledNotifier, bool>(() {
  return LocalAudioEnabledNotifier();
});

class LocalAudioEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
    ref.read(videoControllerProvider.notifier).toggleMicrophone(state);
  }

  void set(bool enabled) {
    state = enabled;
    ref.read(videoControllerProvider.notifier).toggleMicrophone(enabled);
  }
}

/// Local video enabled state
final localVideoEnabledProvider =
    NotifierProvider<LocalVideoEnabledNotifier, bool>(() {
  return LocalVideoEnabledNotifier();
});

class LocalVideoEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void toggle() {
    state = !state;
    ref.read(videoControllerProvider.notifier).toggleCamera(state);
  }

  void set(bool enabled) {
    state = enabled;
    ref.read(videoControllerProvider.notifier).toggleCamera(enabled);
  }
}

/// Remote users provider
final remoteUsersProvider =
    NotifierProvider<RemoteUsersNotifier, List<int>>(() {
  return RemoteUsersNotifier();
});

class RemoteUsersNotifier extends Notifier<List<int>> {
  @override
  List<int> build() => [];

  void addUser(int uid) {
    if (!state.contains(uid)) {
      state = [...state, uid];
    }
  }

  void removeUser(int uid) {
    state = state.where((id) => id != uid).toList();
  }

  void clear() {
    state = [];
  }
}

/// ============================================================================
/// STORAGE/MEDIA PROVIDERS
/// ============================================================================

/// Storage controller for file uploads
final storageControllerProvider =
    NotifierProvider<StorageController, AsyncValue<String?>>(() {
  return StorageController();
});

class StorageController extends Notifier<AsyncValue<String?>> {
  late final StorageService _storageService;

  @override
  AsyncValue<String?> build() {
    _storageService = ref.watch(storageServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Upload image
  Future<String?> uploadImage(XFile file, String userId) async {
    state = const AsyncValue.loading();
    try {
      final url = await _storageService.uploadImage(file, userId);
      state = AsyncValue.data(url);
      return url;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Upload video
  Future<String?> uploadVideo(XFile file, String userId) async {
    state = const AsyncValue.loading();
    try {
      final url = await _storageService.uploadVideo(file, userId);
      state = AsyncValue.data(url);
      return url;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Upload file
  Future<String?> uploadFile(File file, String userId, String fileName) async {
    state = const AsyncValue.loading();
    try {
      final url = await _storageService.uploadFile(file, userId, fileName);
      state = AsyncValue.data(url);
      return url;
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      return null;
    }
  }

  /// Delete file
  Future<void> deleteFile(String url) async {
    try {
      await _storageService.deleteFile(url);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// User media gallery provider
final userMediaProvider =
    StreamProvider.family<List<MediaItem>, String>((ref, userId) async* {
  // Query media collection where userId = userId
  yield [];
});

/// Upload progress provider
final uploadProgressProvider =
    NotifierProvider<UploadProgressNotifier, double>(() {
  return UploadProgressNotifier();
});

class UploadProgressNotifier extends Notifier<double> {
  @override
  double build() => 0.0;

  void updateProgress(double progress) {
    state = progress.clamp(0.0, 1.0);
  }

  void reset() {
    state = 0.0;
  }
}

/// ============================================================================
/// MODERATION PROVIDERS
/// ============================================================================

/// Reports stream provider (admin only)
final reportsProvider = StreamProvider<List<Report>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  // Check if user is admin/moderator
  // Query reports collection
  yield [];
});

/// Pending reports provider
final pendingReportsProvider = StreamProvider<List<Report>>((ref) async* {
  final reports = ref.watch(reportsProvider).value ?? [];
  yield reports.where((r) => r.status == ReportStatus.pending).toList();
});

/// User's blocked users provider
final blockedUsersProvider = StreamProvider<List<Block>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  // Query blocks where blockerId = currentUser.id
  yield [];
});

/// Check if user is blocked provider
final isUserBlockedProvider =
    StreamProvider.family<bool, String>((ref, userId) async* {
  final blockedUsers = ref.watch(blockedUsersProvider).value ?? [];
  yield blockedUsers.any((block) => block.blockedUserId == userId);
});

/// Moderation controller
final moderationControllerProvider =
    NotifierProvider<ModerationController, AsyncValue<void>>(() {
  return ModerationController();
});

class ModerationController extends Notifier<AsyncValue<void>> {
  late final ModerationService _moderationService;

  @override
  AsyncValue<void> build() {
    _moderationService = ref.watch(moderationServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Report a user or content
  Future<void> reportUser({
    required String reportedUserId,
    required ReportType type,
    required String description,
    String? reportedMessageId,
    String? reportedRoomId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final report = Report(
        id: '',
        reporterId: currentUser.id,
        reportedUserId: reportedUserId,
        reportedMessageId: reportedMessageId,
        reportedRoomId: reportedRoomId,
        type: type,
        description: description,
        status: ReportStatus.pending,
        createdAt: DateTime.now(),
      );

      await _moderationService.submitReport(report);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Block a user
  Future<void> blockUser(String blockerId, String blockedUserId,
      {String? reason}) async {
    state = const AsyncValue.loading();
    try {
      await _moderationService.blockUser(blockerId, blockedUserId,
          reason: reason);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String blockerId, String blockedUserId) async {
    try {
      await _moderationService.unblockUser(blockerId, blockedUserId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Review report (admin only)
  Future<void> reviewReport(String reportId, bool resolve) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      await _moderationService.reviewReport(
        reportId,
        currentUser.id,
        resolve ? 'resolved' : 'reviewed',
      );
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Ban user (admin only)
  Future<void> banUser(String moderatorId, String userId, String reason,
      Duration duration) async {
    state = const AsyncValue.loading();
    try {
      await _moderationService.banUser(moderatorId, userId, reason, duration);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Unban user (admin only)
  Future<void> unbanUser(String moderatorId, String userId) async {
    try {
      await _moderationService.unbanUser(moderatorId, userId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }
}

/// Content filter settings provider
final contentFilterSettingsProvider =
    NotifierProvider<ContentFilterSettingsNotifier, Map<String, bool>>(() {
  return ContentFilterSettingsNotifier();
});

class ContentFilterSettingsNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() {
    return {
      'filterProfanity': true,
      'filterSpam': true,
      'filterAdultContent': true,
      'filterViolence': false,
    };
  }

  void updateSetting(String key, bool value) {
    state = {...state, key: value};
  }
}
