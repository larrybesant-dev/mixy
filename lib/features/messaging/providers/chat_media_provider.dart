import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../../core/providers/firebase_providers.dart';
import '../services/chat_media_service.dart';
import '../models/media_message.dart';

// Chat media service provider
final chatMediaServiceProvider = Provider<ChatMediaService>((ref) {
  final storage = ref.watch(firebaseStorageProvider);
  return ChatMediaService(storage: storage);
});

// Upload state controller for tracking upload progress
final chatMediaUploadProvider =
    StateNotifierProvider<ChatMediaUploadController, AsyncValue<MediaMessage?>>((ref) {
  final service = ref.watch(chatMediaServiceProvider);
  return ChatMediaUploadController(service);
});

class ChatMediaUploadController extends StateNotifier<AsyncValue<MediaMessage?>> {
  ChatMediaUploadController(this._service)
      : super(const AsyncValue.data(null));

  final ChatMediaService _service;
  UploadTask? _currentUpload;

  /// Upload an image to Firebase Storage
  Future<MediaMessage?> uploadImage({
    required String conversationId,
    required String userId,
    required Uint8List imageBytes,
    String? fileName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final media = await _service.uploadImage(
        conversationId: conversationId,
        userId: userId,
        imageBytes: imageBytes,
        fileName: fileName,
      );
      state = AsyncValue.data(media);
      return media;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// Cancel current upload
  void cancelUpload() {
    _currentUpload?.cancel();
    state = const AsyncValue.data(null);
  }
}
