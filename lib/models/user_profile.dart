class UserProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final int vipLevel;
  final int followersCount;

  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.vipLevel = 0,
    this.followersCount = 0,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json, String userId) {
    return UserProfile(
      id: userId,
      username: json['username']?.toString() ?? json['displayName']?.toString() ?? 'MixVy Member',
      displayName: json['displayName']?.toString() ?? json['username']?.toString() ?? 'MixVy Member',
      avatarUrl: json['avatarUrl']?.toString() ?? json['photoUrl']?.toString(),
      bio: json['bio']?.toString() ?? json['aboutMe']?.toString(),
      vipLevel: (json['vipLevel'] as num?)?.toInt() ?? 0,
      followersCount: (json['followers'] is List)
          ? (json['followers'] as List).length
          : ((json['followersCount'] as num?)?.toInt() ?? 0),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'displayName': displayName,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'vipLevel': vipLevel,
    'followersCount': followersCount,
  };
}



