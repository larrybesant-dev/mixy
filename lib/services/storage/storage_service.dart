import 'dart:io' show File;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(XFile image, String userId) async {
    try {
      // Defensive guard: recover empty userId from live auth session
      String resolvedId = userId;
      if (resolvedId.isEmpty) {
        resolvedId = FirebaseAuth.instance.currentUser?.uid ?? '';
        debugPrint(
            '⚠️ [StorageService] uploadImage called with empty userId — resolved to: $resolvedId');
        if (resolvedId.isEmpty) {
          throw Exception(
              'Cannot upload image: userId is empty and user is not authenticated');
        }
      }
      final ref = _storage.ref().child(
          'users/$resolvedId/images/${DateTime.now().millisecondsSinceEpoch}.jpg');

      if (kIsWeb) {
        // For web, use bytes instead of file path
        final bytes = await image.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        // For mobile, use file path
        await ref.putFile(File(image.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      final msg = e.toString();
      // Detect CORS errors early with a clear message
      if (kIsWeb && (msg.contains('XMLHttpRequest') || msg.contains('CORS') ||
          msg.contains('NetworkError') || msg.contains('Failed to fetch'))) {
        debugPrint('[StorageService] ⚠️ CORS error — run tools/apply-cors.ps1');
        throw Exception(
            'CORS error: Web uploads blocked. Run tools/apply-cors.ps1 to configure Firebase Storage CORS. Original: $msg');
      }
      debugPrint('[StorageService] uploadImage error: $msg');
      throw Exception('Failed to upload image: $msg');
    }
  }

  Future<String?> uploadVideo(XFile video, String userId) async {
    try {
      final ref = _storage.ref().child(
          'users/$userId/videos/${DateTime.now().millisecondsSinceEpoch}.mp4');

      if (kIsWeb) {
        // For web, use bytes instead of file path
        final bytes = await video.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
      } else {
        // For mobile, use file path
        await ref.putFile(File(video.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload video: $e');
    }
  }

  Future<String?> uploadFile(File file, String userId, String fileName) async {
    try {
      final ref = _storage.ref().child('users/$userId/files/$fileName');
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload file: $e');
    }
  }

  Future<void> deleteFile(String url) async {
    try {
      await _storage.refFromURL(url).delete();
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }

  // Convenience aliases for common naming patterns
  Future<String?> uploadImageFromXFile(XFile image, String userId) =>
      uploadImage(image, userId);

  Future<String?> uploadProfileImageFromXFile(XFile image, String userId) =>
      uploadImage(image, userId);

  // Upload avatar with specific path
  Future<String?> uploadAvatar(XFile image, String userId) async {
    try {
      String resolvedId = userId;
      if (resolvedId.isEmpty) {
        resolvedId = FirebaseAuth.instance.currentUser?.uid ?? '';
        debugPrint(
            '⚠️ [StorageService] uploadAvatar called with empty userId — resolved to: $resolvedId');
        if (resolvedId.isEmpty) {
          throw Exception('Cannot upload avatar: user not authenticated');
        }
      }
      final ref = _storage.ref().child('users/$resolvedId/avatar.jpg');

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(image.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload avatar: $e');
    }
  }

  // Upload cover photo
  Future<String?> uploadCoverPhoto(XFile image, String userId) async {
    try {
      String resolvedId = userId;
      if (resolvedId.isEmpty) {
        resolvedId = FirebaseAuth.instance.currentUser?.uid ?? '';
        debugPrint(
            '⚠️ [StorageService] uploadCoverPhoto called with empty userId — resolved to: $resolvedId');
        if (resolvedId.isEmpty) {
          throw Exception('Cannot upload cover photo: user not authenticated');
        }
      }
      final ref = _storage.ref().child('users/$resolvedId/cover.jpg');

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(image.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload cover photo: $e');
    }
  }

  // Upload gallery photo
  Future<String?> uploadGalleryPhoto(XFile image, String userId) async {
    try {
      String resolvedId = userId;
      if (resolvedId.isEmpty) {
        resolvedId = FirebaseAuth.instance.currentUser?.uid ?? '';
        debugPrint(
            '⚠️ [StorageService] uploadGalleryPhoto called with empty userId — resolved to: $resolvedId');
        if (resolvedId.isEmpty) {
          throw Exception(
              'Cannot upload gallery photo: user not authenticated');
        }
      }
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref =
          _storage.ref().child('users/$resolvedId/gallery/$timestamp.jpg');

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      } else {
        await ref.putFile(File(image.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload gallery photo: $e');
    }
  }

  // Upload gallery video
  Future<String?> uploadGalleryVideo(XFile video, String userId) async {
    try {
      String resolvedId = userId;
      if (resolvedId.isEmpty) {
        resolvedId = FirebaseAuth.instance.currentUser?.uid ?? '';
        debugPrint(
            '⚠️ [StorageService] uploadGalleryVideo called with empty userId — resolved to: $resolvedId');
        if (resolvedId.isEmpty) {
          throw Exception(
              'Cannot upload gallery video: userId is empty and user is not authenticated');
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ref =
          _storage.ref().child('users/$resolvedId/gallery/$timestamp.mp4');

      if (kIsWeb) {
        final bytes = await video.readAsBytes();
        await ref.putData(bytes, SettableMetadata(contentType: 'video/mp4'));
      } else {
        await ref.putFile(File(video.path));
      }

      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to upload gallery video: $e');
    }
  }
}
