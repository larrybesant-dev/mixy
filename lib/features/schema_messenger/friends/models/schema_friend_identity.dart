class SchemaFriendIdentity {
  const SchemaFriendIdentity({
    required this.userId,
    required this.username,
    this.email,
    this.avatarUrl,
    this.accentColor,
  });

  final String userId;
  final String username;
  final String? email;
  final String? avatarUrl;
  final String? accentColor;

  factory SchemaFriendIdentity.fromMaps({
    required String userId,
    required Map<String, dynamic> userData,
    required Map<String, dynamic>? profilePublicData,
  }) {
    final profileData = profilePublicData ?? const <String, dynamic>{};
    return SchemaFriendIdentity(
      userId: userId,
      username: _asString(userData['username'], fallback: 'Unknown user'),
      email: _asNullableString(userData['email']),
      avatarUrl:
          _asNullableString(profileData['avatarUrl']) ??
          _asNullableString(userData['avatarUrl']),
      accentColor: _asNullableString(profileData['profileAccentColor']),
    );
  }

  static String _asString(dynamic value, {String fallback = ''}) {
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }
    return fallback;
  }

  static String? _asNullableString(dynamic value) {
    final normalized = _asString(value);
    return normalized.isEmpty ? null : normalized;
  }
}
