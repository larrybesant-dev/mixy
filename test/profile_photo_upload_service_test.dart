import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/services/profile_photo_upload_service.dart';

class _Storage extends Mock implements FirebaseStorage {}

class _Reference extends Mock implements Reference {}

class _UploadTask extends Mock implements UploadTask {}

class _Snapshot extends Mock implements TaskSnapshot {}

void main() {
  setUpAll(() => registerFallbackValue(Duration.zero));
  Uint8List photo(int width, int height) => Uint8List.fromList(
        img.encodePng(img.Image(width: width, height: height)),
      );

  group('Profile photo preparation', () {
    test('converts PNG bytes to JPEG rather than relabeling the original', () {
      final result = FirebaseProfilePhotoUploadService.preparePhoto(
        photo(80, 60),
        folder: 'profile_photos',
      );
      expect(result.take(2), [0xff, 0xd8]);
      expect(img.decodeJpg(result)?.width, 80);
      expect(result.length, lessThan(5 * 1024 * 1024));
    });

    test('bounds large desktop gallery photos while preserving aspect ratio',
        () {
      final result = FirebaseProfilePhotoUploadService.preparePhoto(
        photo(2400, 1200),
        folder: 'gallery_photos',
      );
      final decoded = img.decodeJpg(result);
      expect(decoded?.width, 1600);
      expect(decoded?.height, 800);
      expect(result.length, lessThan(5 * 1024 * 1024));
    });

    test('crops covers to the existing 1200 by 525 layout', () {
      final result = FirebaseProfilePhotoUploadService.preparePhoto(
        photo(100, 180),
        folder: 'cover_photos',
      );
      final decoded = img.decodeJpg(result);
      expect(decoded?.width, 1200);
      expect(decoded?.height, 525);
    });

    test('rejects unreadable bytes explicitly', () {
      expect(
        () => FirebaseProfilePhotoUploadService.preparePhoto(
          Uint8List.fromList([1, 2, 3]),
          folder: 'gallery_photos',
        ),
        throwsA(isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'invalid-image',
        )),
      );
    });

    test('rejects files above the input limit before decoding', () {
      expect(
        () => FirebaseProfilePhotoUploadService.preparePhoto(
          Uint8List(FirebaseProfilePhotoUploadService.maxInputBytes + 1),
          folder: 'profile_photos',
        ),
        throwsA(isA<FirebaseException>().having(
          (e) => e.code,
          'code',
          'photo-too-large',
        )),
      );
    });
  });

  test('uploads JPEG bytes to Storage and returns the durable download URL',
      () async {
    final storage = _Storage();
    final reference = _Reference();
    final task = _UploadTask();
    const url = 'https://storage.example.test/gallery/photo.jpg';
    String? path;
    Uint8List? uploaded;
    SettableMetadata? metadata;
    when(() => storage.ref(any())).thenAnswer((invocation) {
      path = invocation.positionalArguments.first as String;
      return reference;
    });
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(SettableMetadata());
    when(() => reference.putData(any(), any())).thenAnswer((invocation) {
      uploaded = invocation.positionalArguments[0] as Uint8List;
      metadata = invocation.positionalArguments[1] as SettableMetadata;
      return task;
    });
    when(() => task.timeout(any())).thenAnswer((_) async => _Snapshot());
    when(() => reference.getDownloadURL()).thenAnswer((_) async => url);

    final result = await FirebaseProfilePhotoUploadService(storage).upload(
      bytes: photo(80, 60),
      userId: 'tester',
      folder: 'gallery_photos',
    );
    expect(result, url);
    expect(path, startsWith('users/tester/gallery_photos/'));
    expect(path, endsWith('.jpg'));
    expect(uploaded?.take(2), [0xff, 0xd8]);
    expect(metadata?.contentType, 'image/jpeg');
  });
}
