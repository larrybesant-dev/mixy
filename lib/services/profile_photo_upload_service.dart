import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;

import '../core/providers/firebase_providers.dart';

abstract class ProfilePhotoUploadService {
  Future<String> upload({
    required Uint8List bytes,
    required String userId,
    required String folder,
  });
}

final profilePhotoUploadServiceProvider = Provider<ProfilePhotoUploadService>(
  (ref) => FirebaseProfilePhotoUploadService(
    ref.watch(firebaseStorageProvider),
  ),
);

class FirebaseProfilePhotoUploadService implements ProfilePhotoUploadService {
  FirebaseProfilePhotoUploadService(this._storage);

  static const maxInputBytes = 20 * 1024 * 1024;
  static const maxUploadBytes = 5 * 1024 * 1024;
  static const folders = {
    'profile_photos',
    'cover_photos',
    'gallery_photos',
  };

  final FirebaseStorage _storage;

  static FirebaseException _invalidImage() => FirebaseException(
        plugin: 'firebase_storage',
        code: 'invalid-image',
        message: 'This photo could not be read. Choose a JPEG, PNG, or WebP.',
      );

  static Uint8List preparePhoto(Uint8List bytes, {required String folder}) {
    if (!folders.contains(folder)) {
      throw ArgumentError.value(folder, 'folder', 'Unsupported photo folder');
    }
    if (bytes.isEmpty || bytes.lengthInBytes > maxInputBytes) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'photo-too-large',
        message: 'Choose a photo under 20MB.',
      );
    }
    img.Image? decoded;
    try {
      decoded = img.decodeImage(bytes);
    } on RangeError {
      throw _invalidImage();
    } on img.ImageException {
      throw _invalidImage();
    } on FormatException {
      throw _invalidImage();
    }
    if (decoded == null || decoded.width <= 0 || decoded.height <= 0) {
      throw _invalidImage();
    }

    var image = img.bakeOrientation(decoded);
    if (folder == 'cover_photos') {
      const aspect = 16 / 7;
      final width = image.width / image.height > aspect
          ? (image.height * aspect).round()
          : image.width;
      final height = image.width / image.height > aspect
          ? image.height
          : (image.width / aspect).round();
      image = img.copyCrop(
        image,
        x: (image.width - width) ~/ 2,
        y: (image.height - height) ~/ 2,
        width: width.clamp(1, image.width),
        height: height.clamp(1, image.height),
      );
      image = img.copyResize(image, width: 1200, height: 525);
    } else if (image.width > 1600 || image.height > 1600) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? 1600 : null,
        height: image.height > image.width ? 1600 : null,
      );
    }

    final encoded = Uint8List.fromList(img.encodeJpg(image, quality: 85));
    if (encoded.lengthInBytes >= maxUploadBytes) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'photo-too-large',
        message: 'This photo is too large to upload. Choose a smaller photo.',
      );
    }
    return encoded;
  }

  @override
  Future<String> upload({
    required Uint8List bytes,
    required String userId,
    required String folder,
  }) async {
    if (userId.trim().isEmpty) {
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'unauthenticated',
        message: 'Please sign in again before uploading.',
      );
    }
    final prepared = preparePhoto(bytes, folder: folder);
    final photoRef = _storage.ref(
      'users/$userId/$folder/${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final task = photoRef.putData(
      prepared,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    try {
      await task.timeout(const Duration(seconds: 45));
    } on TimeoutException {
      await task.cancel();
      throw FirebaseException(
        plugin: 'firebase_storage',
        code: 'retry-limit-exceeded',
        message: 'Photo upload timed out. Check your connection and try again.',
      );
    }
    return photoRef.getDownloadURL().timeout(const Duration(seconds: 20));
  }
}
