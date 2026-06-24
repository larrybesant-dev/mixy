// lib/features/profile/repositories/profile_repository.dart
//
// Firestore implementation of IProfileRepository.
// UID validation happens here before every write — never in the UI.
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mixvy/shared/models/user_profile.dart';
import 'i_profile_repository.dart';

class ProfileRepository implements IProfileRepository {
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  ProfileRepository({
    FirebaseFirestore? db,
    FirebaseStorage? storage,
  })  : _db = db ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> get _users =>
      _db.collection('users');

  @override
  Future<UserProfile?> getProfile(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromMap(doc.data()!);
  }

  @override
  Stream<UserProfile?> watchProfile(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserProfile.fromMap(doc.data()!);
    });
  }

  @override
  Future<void> setProfile(UserProfile profile) {
    _assertUid(profile.id);
    return _users.doc(profile.id).set(profile.toMap());
  }

  @override
  Future<void> updateProfile({
    required String uid,
    required Map<String, dynamic> fields,
  }) {
    _assertUid(uid);
    return _users.doc(uid).update({
      ...fields,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<String> uploadAvatar({
    required String uid,
    required List<int> imageBytes,
    required String mimeType,
  }) async {
    _assertUid(uid);
    final ref = _storage.ref().child('avatars/$uid/profile.jpg');
    final task = await ref.putData(
      Uint8List.fromList(imageBytes),
      SettableMetadata(contentType: mimeType),
    );
    return task.ref.getDownloadURL();
  }

  @override
  Future<void> deleteProfile(String uid) {
    _assertUid(uid);
    return _users.doc(uid).delete();
  }

  @override
  Future<List<UserProfile>> searchByName(String query, {int limit = 20}) async {
    final snapshot = await _users
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThan: '${query}z')
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => UserProfile.fromMap(d.data())).toList();
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------
  void _assertUid(String uid) {
    if (uid.trim().isEmpty) throw ArgumentError('UID must not be empty');
  }
}

final profileRepositoryProvider = Provider<IProfileRepository>(
  (ref) => ProfileRepository(),
);

