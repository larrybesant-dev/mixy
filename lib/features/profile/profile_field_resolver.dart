String? resolveProfileAvatarUrl(Map<String, dynamic> profileData) {
  for (final field in const ['avatarUrl', 'photoUrl']) {
    final value = profileData[field];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}