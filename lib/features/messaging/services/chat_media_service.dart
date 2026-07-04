import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/media_message.dart';

class ChatMediaService {
  ChatMediaService({required FirebaseStorage storage}) : _storage = storage;

  final FirebaseStorage _storage;
  static const _uuid = Uuid();

  /// Upload an image to Firebase Storage
  /// Returns MediaMessage with URL and thumbnail
  Future<MediaMessage> uploadImage({
    required String conversationId,
    required String userId,
    required Uint8List imageBytes,
    String? fileName,
  }) async {
    final mediaId = _uuid.v4();
    final timestamp = DateTime.now().toIso8601String();
    final path = 'conversations/$conversationId/media/$timestamp-$fileName';

    try {
      // Upload image
      final ref = _storage.ref().child(path);
      final uploadTask = ref.putData(imageBytes, SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: {
          'uploadedBy': userId,
          'conversationId': conversationId,
          'type': 'image',
        },
      ));

      await uploadTask;
      final url = await ref.getDownloadURL();

      return MediaMessage(
        id: mediaId,
        mediaUrl: url,
        mediaType: 'image',
        fileSizeBytes: imageBytes.length,
        thumbnailUrl: url, // For now, use same URL (could generate thumbnail)
        createdAt: DateTime.now(),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Delete media from Firebase Storage
  Future<void> deleteMedia(String mediaUrl) async {
    try {
      final ref = _storage.refFromURL(mediaUrl);
      await ref.delete();
    } catch (e) {
      rethrow;
    }
  }

  /// Get download URL for a media file
  Future<String> getDownloadUrl(String path) async {
    final ref = _storage.ref().child(path);
    return await ref.getDownloadURL();
  }

  /// Get file metadata
  Future<FullMetadata?> getMediaMetadata(String mediaUrl) async {
    try {
      final ref = _storage.refFromURL(mediaUrl);
      return await ref.getMetadata();
    } catch (e) {
      return null;
    }
  }
}
