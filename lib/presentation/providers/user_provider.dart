import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final userProvider = Provider<UserModel?>((ref) {
  final authState = ref.watch(authControllerProvider);
  final profileState = ref.watch(profileControllerProvider);
  // Use AuthController as the single source of truth for session identity.
  final uid = authState.uid;

  if (uid == null) {
    return null;
  }

  final resolvedUsername = resolvePublicUsername(
    uid: uid,
    profileUsername: profileState.username,
    authDisplayName: null,
  );

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
