import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/firebase_providers.dart';
import '../../features/auth/controllers/auth_controller.dart';
import '../../features/profile/profile_controller.dart';
import '../../models/user_model.dart';

bool isAnonymousDisplayName(String value) {
  final normalized = value.trim();
  final generatedHandlePattern = RegExp(r'^(User|Guest|Member) [A-Z0-9]{1,4}$');
  final opaqueIdPattern = RegExp(r'^[A-Za-z0-9_-]{20,}$');
  return normalized.isEmpty ||
      normalized == 'MixVy User' ||
      normalized == 'MixVy Member' ||
      generatedHandlePattern.hasMatch(normalized) ||
      opaqueIdPattern.hasMatch(normalized);
}

String getDisplayName({
  required String uid,
  String? resolvedDisplayName,
  String? profileUsername,
  String? authDisplayName,
  String? fallbackName,
}) {
  final normalizedResolved = resolvedDisplayName?.trim() ?? '';
  if (normalizedResolved.isNotEmpty &&
      !isAnonymousDisplayName(normalizedResolved)) {
    return normalizedResolved;
  }

  final normalizedFallback = fallbackName?.trim() ?? '';
  if (normalizedFallback.isNotEmpty &&
      !isAnonymousDisplayName(normalizedFallback)) {
    return normalizedFallback;
  }

  return resolvePublicUsername(
    uid: uid,
    profileUsername: profileUsername,
    authDisplayName: authDisplayName,
  );
}

String resolvePublicUsername({
  required String uid,
  String? profileUsername,
  String? authDisplayName,
}) {
  final normalizedUid = uid.trim();
  final normalizedProfile = profileUsername?.trim() ?? '';
  final normalizedAuthDisplayName = authDisplayName?.trim() ?? '';

  if (normalizedProfile.isNotEmpty &&
      !isAnonymousDisplayName(normalizedProfile)) {
    return normalizedProfile;
  }

  if (normalizedAuthDisplayName.isNotEmpty &&
      !isAnonymousDisplayName(normalizedAuthDisplayName)) {
    return normalizedAuthDisplayName;
  }

  if (normalizedUid.isEmpty) {
    return 'MixVy Member';
  }

  final compactUid = normalizedUid
      .replaceAll(RegExp(r'[^A-Za-z0-9]'), '')
      .toUpperCase();
  final suffix = compactUid.isEmpty
      ? ''
      : compactUid.substring(0, compactUid.length < 4 ? compactUid.length : 4);
  return suffix.isEmpty ? 'MixVy Member' : 'Member $suffix';
}

/// Provides the current authenticated user with resolved displayName from RTDB.
///
/// This provider orchestrates data from three sources:
/// 1. **AuthController**: Authentication state + UID
/// 2. **ProfileController**: Cached profile data (username, email, avatar)
/// 3. **RTDB displayNameStream**: Real-time displayName from `/users/{uid}/displayName`
///
/// The displayName priority is:
/// - displayName from RTDB (source of truth)
/// - username from ProfileController
/// - email handle
/// - UID-based fallback
///
/// This ensures the router always has a complete, non-placeholder displayName
/// before navigation is allowed.
final userProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final profileState = ref.watch(profileControllerProvider);
  
  final uid = authState.uid;
  if (uid == null || uid.isEmpty) {
    return null;
  }

  // Watch displayName from RTDB.
  // This is a StreamProvider.autoDispose, so it will emit AsyncValue<String?>.
  final displayNameAsync = ref.watch(displayNameStreamProvider(uid));

  // Extract the actual displayName value from AsyncValue.
  final rtdbDisplayName = displayNameAsync.maybeWhen(
    data: (name) => name,
    orElse: () => null,
  );

  // Build resolved username: RTDB displayName takes priority.
  final resolvedUsername = rtdbDisplayName ??
      resolvePublicUsername(
        uid: uid,
        profileUsername: profileState.username,
        authDisplayName: null,
      );

  // Use avatar if it belongs to the current user.
  final profileAvatar =
      (profileState.userId == uid || profileState.userId == null) &&
          (profileState.avatarUrl?.isNotEmpty == true)
      ? profileState.avatarUrl
      : null;

  return UserModel(
    id: uid,
    email: profileState.email ?? '',
    username: resolvedUsername,
    avatarUrl: profileAvatar,
    createdAt: DateTime.now(),
  );
});




