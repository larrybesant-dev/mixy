class SchemaMigrationFlags {
  const SchemaMigrationFlags._();

  static const bool strictWriteAuthority = bool.fromEnvironment(
    'MIXVY_STRICT_WRITE_AUTHORITY',
    defaultValue: false,
  );

  static const bool enableProfileLegacyWrite = bool.fromEnvironment(
    'MIXVY_ENABLE_PROFILE_LEGACY_WRITE',
    defaultValue: false,
  );

  static const bool enableFriendLegacyWrite = bool.fromEnvironment(
    'MIXVY_ENABLE_FRIEND_LEGACY_WRITE',
    defaultValue: false,
  );

  static const bool enableVerificationLegacyRead = bool.fromEnvironment(
    'MIXVY_ENABLE_VERIFICATION_LEGACY_READ',
    defaultValue: true,
  );

  static const bool enableUsersShadowMerge = bool.fromEnvironment(
    'MIXVY_ENABLE_USERS_SHADOW_MERGE',
    defaultValue: true,
  );

  static const bool enableAvatarLegacyWrite = bool.fromEnvironment(
    'MIXVY_ENABLE_AVATAR_LEGACY_WRITE',
    defaultValue: false,
  );
}
