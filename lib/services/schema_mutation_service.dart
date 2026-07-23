import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/schema_migration_flags.dart';
import '../core/telemetry/app_telemetry.dart';
import '../features/friends/models/friendship_model.dart';
import '../models/adult_profile_model.dart';
import '../models/profile_privacy_model.dart';

class SchemaMutationService {
  SchemaMutationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const Set<String> _identityFields = <String>{
    'uid',
    'username',
    'usernameLower',
    'displayName',
    'email',
    'photoUrl',
    'bio',
    'isPrivate',
    'isComplete',
  };

  static const Set<String> _profilePublicFields = <String>{
    'avatarUrl',
    'coverPhotoUrl',
    'galleryUrls',
    'introVideoUrl',
    'aboutMe',
    'age',
    'gender',
    'location',
    'relationshipStatus',
    'vibePrompt',
    'firstDatePrompt',
    'musicTastePrompt',
    'interests',
  };

  static const Set<String> _preferencesFields = <String>{
    'themeId',
    'camViewPolicy',
    'profileAccentColor',
    'profileBgGradientStart',
    'profileBgGradientEnd',
    'profileMusicUrl',
    'profileMusicTitle',
    'topEightIds',
    // Adult-mode preferences are stored in preferences/{userId}, NOT in the
    // server-managed /verification/{userId} collection (client writes blocked).
    'adultModeEnabled',
    'adultConsentAccepted',
  };

  static const Set<String> _verificationFields = <String>{};

  static const Set<String> _knownProfileWriteFields = <String>{
    ..._identityFields,
    ..._profilePublicFields,
    ..._preferencesFields,
    ..._verificationFields,
  };

  Future<void> createUserProfile({
    required User user,
    String? preferredUsername,
    bool? mirrorLegacyAvatarInUsers,
  }) async {
    final userRef = _firestore.collection('users').doc(user.uid);
    final profilePublicRef = _firestore
        .collection('profile_public')
        .doc(user.uid);

    final userSnapshot = await userRef.get();
    final now = FieldValue.serverTimestamp();
    final existingData = userSnapshot.data() ?? const <String, dynamic>{};
    final existingUsername = _normalizeUsername(
      (existingData['username'] as String?)?.trim(),
    );
    final existingDisplayName = _normalizeUsername(
      (existingData['displayName'] as String?)?.trim(),
    );
    final authDisplayName = _normalizeUsername(user.displayName);
    final emailHandle = _emailHandleFrom(user.email);
    final normalizedPreferredUsername = _normalizeUsername(preferredUsername);
    final shouldReplaceAutofilledName =
        existingUsername.isEmpty ||
        _isPlaceholderPublicUsername(existingUsername);
    final publicUsername = shouldReplaceAutofilledName
        ? _resolvePublicUsername(
            preferredUsername: normalizedPreferredUsername,
            authDisplayName: authDisplayName,
            emailHandle: emailHandle,
            uid: user.uid,
          )
        : _resolvePublicUsername(
            preferredUsername: existingUsername,
            authDisplayName: authDisplayName,
            emailHandle: emailHandle,
            uid: user.uid,
          );
    final publicDisplayName = existingDisplayName.isNotEmpty
        ? existingDisplayName
        : (authDisplayName.isNotEmpty ? authDisplayName : publicUsername);
    final isComplete =
        existingData['isComplete'] == true ||
        normalizedPreferredUsername.isNotEmpty;

    final identityPayload = <String, dynamic>{
      'uid': user.uid,
      'username': publicUsername,
      'usernameLower': publicUsername.toLowerCase(),
      'displayName': publicDisplayName,
      'email': user.email ?? '',
      'photoUrl': user.photoURL ?? existingData['photoUrl'],
      'isComplete': isComplete,
      'updatedAt': now,
    };

    if (mirrorLegacyAvatarInUsers ??
        SchemaMigrationFlags.enableAvatarLegacyWrite) {
      identityPayload['avatarUrl'] = user.photoURL;
      _logEnforcementEvent(
        action: 'legacy_avatar_mirror_write',
        userId: user.uid,
        metadata: <String, Object?>{'target': 'users.avatarUrl'},
      );
    }

    await userRef.set({
      ...identityPayload,
      if (!userSnapshot.exists) 'id': user.uid,
      if (!userSnapshot.exists) 'createdAt': now,
    }, SetOptions(merge: true));

    await profilePublicRef.set({
      'userId': user.uid,
      'avatarUrl': user.photoURL,
      'updatedAt': now,
      if (!(await profilePublicRef.get()).exists) 'createdAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> updateProfilePublic({
    required String userId,
    required Map<String, dynamic> userData,
    required ProfilePrivacyModel privacy,
    required AdultProfileModel adultProfile,
    bool? mirrorLegacyUserDoc,
  }) async {
    final usersRef = _firestore.collection('users').doc(userId);
    final profilePublicRef = _firestore
        .collection('profile_public')
        .doc(userId);
    final preferencesRef = _firestore.collection('preferences').doc(userId);
    final privacyRef = usersRef.collection('privacy').doc('settings');
    final adultRef = usersRef.collection('adult_profile').doc('details');

    final now = FieldValue.serverTimestamp();

    _validateKnownProfileFields(userData: userData, userId: userId);

    final identityPayload = _pickAllowedFields(
      userData: userData,
      allowedFields: _identityFields,
    )..['updatedAt'] = now;

    final profilePublicPayload = _pickAllowedFields(
      userData: userData,
      allowedFields: _profilePublicFields,
    )..addAll(<String, dynamic>{'userId': userId, 'updatedAt': now});

    profilePublicPayload['galleryUrls'] =
        userData['galleryUrls'] ?? const <dynamic>[];
    profilePublicPayload['interests'] =
        userData['interests'] ?? const <dynamic>[];

    final preferencesPayload = _pickAllowedFields(
      userData: userData,
      allowedFields: _preferencesFields,
    )..addAll(<String, dynamic>{'userId': userId, 'updatedAt': now});

    // _verificationFields is empty — verification/{userId} is server-managed
    // (admin SDK only). Do NOT write to it from the client; Firestore rules
    // block all client writes to that collection.

    final batch = _firestore.batch();

    batch.set(usersRef, identityPayload, SetOptions(merge: true));
    batch.set(profilePublicRef, profilePublicPayload, SetOptions(merge: true));
    batch.set(preferencesRef, preferencesPayload, SetOptions(merge: true));

    // Preserve existing runtime paths while migration is in progress.
    batch.set(privacyRef, {
      ...privacy.toJson(),
      'updatedAt': now,
    }, SetOptions(merge: true));
    batch.set(adultRef, {
      ...adultProfile.toJson(),
      'updatedAt': now,
    }, SetOptions(merge: true));

    if (mirrorLegacyUserDoc ?? SchemaMigrationFlags.enableProfileLegacyWrite) {
      batch.set(usersRef, {
        ...userData,
        'updatedAt': now,
      }, SetOptions(merge: true));
      _logEnforcementEvent(
        action: 'legacy_profile_mirror_write',
        userId: userId,
        metadata: <String, Object?>{'target': 'users/*'},
      );
    }

    await batch.commit();
  }

  Future<void> setVerificationStatus({
    required String userId,
    required bool isVerified,
    String? verifiedBy,
    bool? mirrorLegacyUsersDoc,
  }) async {
    // GUARD: /verification/{userId} is server-only. Firestore rules block ALL
    // client writes to this collection. Calling this method from the Flutter
    // client will always result in a PERMISSION_DENIED error. Verification
    // status must be set via a Cloud Function using the Firebase Admin SDK.
    // See: functions/src/verification/ for the correct server-side path.
    throw UnsupportedError(
      'setVerificationStatus() must not be called from the Flutter client. '
      'Write to verification/{userId} via a Cloud Function (Admin SDK only). '
      'Firestore rules unconditionally deny client writes to this collection.',
    );
    // ignore: dead_code
    final verificationRef = _firestore.collection('verification').doc(userId);
    final usersRef = _firestore.collection('users').doc(userId);

    final now = FieldValue.serverTimestamp();
    await verificationRef.set({
      'userId': userId,
      'isVerified': isVerified,
      'verifiedAt': isVerified ? now : FieldValue.delete(),
      'verifiedBy': isVerified ? verifiedBy : FieldValue.delete(),
      'updatedAt': now,
    }, SetOptions(merge: true));

    // Legacy mirror is opt-in only. Disabled by default because the users doc
    // whitelist does not allow isVerified/verifiedAt fields client-side.
    // This path must only be invoked from Cloud Functions (admin SDK) if needed.
    final shouldMirrorUsersDoc = mirrorLegacyUsersDoc ?? false;
    if (shouldMirrorUsersDoc) {
      await usersRef.set({
        'isVerified': isVerified,
        'verifiedAt': isVerified ? now : FieldValue.delete(),
        'verifiedBy': isVerified ? verifiedBy : FieldValue.delete(),
      }, SetOptions(merge: true));
      _logEnforcementEvent(
        action: 'legacy_verification_mirror_write',
        userId: userId,
        metadata: <String, Object?>{'target': 'users.isVerified'},
      );
    }
  }

  Future<void> setLegacyFavoriteFriend({
    required String userId,
    required String friendId,
    required bool isFavorite,
  }) async {
    if (!SchemaMigrationFlags.enableFriendLegacyWrite) {
      _logEnforcementEvent(
        action: 'legacy_friend_write_blocked',
        userId: userId,
        result: 'disabled',
        metadata: <String, Object?>{'friendId': friendId},
      );
      return;
    }

    await _firestore.collection('users').doc(userId).set({
      'favoriteFriendIds': isFavorite
          ? FieldValue.arrayUnion(<String>[friendId])
          : FieldValue.arrayRemove(<String>[friendId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _logEnforcementEvent(
      action: 'legacy_friend_write',
      userId: userId,
      metadata: <String, Object?>{
        'friendId': friendId,
        'isFavorite': isFavorite,
        'target': 'users.favoriteFriendIds',
      },
    );
  }

  Future<void> syncFriendLinks({
    required String firstUserId,
    required String secondUserId,
    required String status,
    required String requestedBy,
    String collectionName = 'friendships',
  }) async {
    if (status != 'pending' && status != 'accepted' && status != 'blocked') {
      throw StateError('Invalid friend link status: $status');
    }

    final sortedPair = FriendshipModel.sortedPair(firstUserId, secondUserId);
    final linkId = FriendshipModel.canonicalIdFor(firstUserId, secondUserId);
    final normalizedCollectionName = collectionName.trim().isEmpty
        ? 'friendships'
        : collectionName.trim();
    final now = FieldValue.serverTimestamp();

    final schemaPayload = <String, dynamic>{
      'users': <String>[sortedPair.userA, sortedPair.userB],
      'status': status,
      'requestedBy': requestedBy,
      if (status == 'pending') 'createdAt': now,
      'updatedAt': now,
    };

    final legacyPayload = <String, dynamic>{
      'userA': sortedPair.userA,
      'userB': sortedPair.userB,
      'status': status,
      'requestedBy': requestedBy,
      if (status == 'pending') 'createdAt': now,
      'updatedAt': now,
    };

    final batch = _firestore.batch();
    batch.set(
      _firestore.collection('friend_links').doc(linkId),
      schemaPayload,
      SetOptions(merge: true),
    );

    if (SchemaMigrationFlags.enableFriendLegacyWrite ||
        normalizedCollectionName != 'friend_links') {
      batch.set(
        _firestore.collection(normalizedCollectionName).doc(linkId),
        legacyPayload,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  String _normalizeUsername(String? value) {
    final normalized = (value ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');
    return normalized;
  }

  String _emailHandleFrom(String? email) {
    final normalized = (email ?? '').trim();
    if (normalized.isEmpty || !normalized.contains('@')) {
      return '';
    }
    return _normalizeUsername(normalized.split('@').first);
  }

  String _resolvePublicUsername({
    String? preferredUsername,
    String? authDisplayName,
    String? emailHandle,
    required String uid,
  }) {
    for (final candidate in <String?>[
      preferredUsername,
      authDisplayName,
      emailHandle,
    ]) {
      final normalized = _normalizeUsername(candidate);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return _fallbackPublicUsername(uid);
  }

  bool _isPlaceholderPublicUsername(String value) {
    final normalized = value.trim();
    final generatedHandlePattern = RegExp(
      r'^(User|Guest|Member) [A-Z0-9]{1,4}$',
    );
    return normalized.isEmpty ||
        normalized == 'MixVy User' ||
        normalized == 'MixVy Member' ||
        generatedHandlePattern.hasMatch(normalized);
  }

  String _fallbackPublicUsername(String uid) {
    final compactUid = uid
        .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
        .toUpperCase();
    if (compactUid.isEmpty) {
      return 'MixVy Member';
    }
    final suffix = compactUid.substring(
      0,
      compactUid.length < 4 ? compactUid.length : 4,
    );
    return 'Member $suffix';
  }

  Map<String, dynamic> _pickAllowedFields({
    required Map<String, dynamic> userData,
    required Set<String> allowedFields,
  }) {
    final payload = <String, dynamic>{};

    for (final entry in userData.entries) {
      if (allowedFields.contains(entry.key)) {
        payload[entry.key] = entry.value;
      }
    }

    return payload;
  }

  void _validateKnownProfileFields({
    required Map<String, dynamic> userData,
    required String userId,
  }) {
    final unknownKeys = userData.keys
        .where((key) => !_knownProfileWriteFields.contains(key))
        .toList(growable: false);

    if (unknownKeys.isEmpty) {
      return;
    }

    final message =
        'SchemaMutationService blocked unknown profile keys user=$userId keys=$unknownKeys';

    _logEnforcementEvent(
      level: SchemaMigrationFlags.strictWriteAuthority ? 'error' : 'warning',
      action: 'blocked_unknown_profile_keys',
      userId: userId,
      result: SchemaMigrationFlags.strictWriteAuthority
          ? 'blocked'
          : 'quarantined',
      metadata: <String, Object?>{'keys': unknownKeys.join(',')},
    );

    if (SchemaMigrationFlags.strictWriteAuthority) {
      throw StateError(message);
    }

    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // ── message / Conversations domain ───────────────────────────────────────

  /// Creates or opens a direct conversation between [initiatorId] and [recipientId].
  /// Returns the canonical conversation document ID.
  ///
  /// Write path: conversations/{canonicalId}
  /// Forbidden: writing user identity fields, wallet fields, or verification fields.
  Future<String> createDirectConversation({
    required String initiatorId,
    required String recipientId,
    Map<String, String> participantNames = const <String, String>{},
  }) async {
    throw UnsupportedError(
      'SchemaMutationService.createDirectConversation is deprecated. Use MessagingController.createDirectConversation.',
    );
  }

  /// Sends a message to an existing conversation.
  ///
  /// Write paths:
  ///   conversations/{conversationId}/message/{messageId}
  ///   conversations/{conversationId} — updates lastMessage* fields only.
  ///
  /// Forbidden: any field outside [_messageEntryFields] or [_conversationsFields].
  Future<void> sendmessage({
    required String conversationId,
    required String senderId,
    required String text,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    throw UnsupportedError(
      'SchemaMutationService.sendmessage is deprecated. Use MessagingController.sendmessage.',
    );
  }

  /// Marks all message up to [upToTime] as read for [userId] in [conversationId].
  Future<void> markConversationRead({
    required String conversationId,
    required String userId,
  }) async {
    throw UnsupportedError(
      'SchemaMutationService.markConversationRead is deprecated. Use MessagingController.markAsRead.',
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  void _logEnforcementEvent({
    String level = 'info',
    required String action,
    required String userId,
    String? result,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) {
    AppTelemetry.logEnforcementEvent(
      level: level,
      action: action,
      message: 'Schema mutation enforcement event.',
      userId: userId,
      result: result,
      metadata: metadata,
    );
  }

  Future<void> updateTopEight({
    required String userId,
    required List<String> topEightIds,
  }) async {
    final now = FieldValue.serverTimestamp();
    final batch = _firestore.batch();

    batch.set(
      _firestore.collection('users').doc(userId),
      {
        'topEightIds': topEightIds,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    // Also mirror to preferences as this is considered a personalization feature.
    batch.set(
      _firestore.collection('preferences').doc(userId),
      {
        'topEightIds': topEightIds,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await batch.commit();

    _logEnforcementEvent(
      action: 'top_eight_update',
      userId: userId,
      metadata: <String, Object?>{'count': topEightIds.length},
    );
  }
}



