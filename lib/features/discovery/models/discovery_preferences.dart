import 'package:cloud_firestore/cloud_firestore.dart';

class DiscoveryPreferences {
  final String userId;
  final int minAge;
  final int maxAge;
  final List<String> interestTags;
  final DateTime? updatedAt;

  const DiscoveryPreferences({
    required this.userId,
    this.minAge = 18,
    this.maxAge = 99,
    this.interestTags = const [],
    this.updatedAt,
  });

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'minAge': minAge,
        'maxAge': maxAge,
        'interestTags': interestTags,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  factory DiscoveryPreferences.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return DiscoveryPreferences(
      userId: doc.id,
      minAge: (data['minAge'] as int?) ?? 18,
      maxAge: (data['maxAge'] as int?) ?? 99,
      interestTags: List<String>.from(data['interestTags'] as List? ?? []),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  DiscoveryPreferences copyWith({
    String? userId,
    int? minAge,
    int? maxAge,
    List<String>? interestTags,
    DateTime? updatedAt,
  }) =>
      DiscoveryPreferences(
        userId: userId ?? this.userId,
        minAge: minAge ?? this.minAge,
        maxAge: maxAge ?? this.maxAge,
        interestTags: interestTags ?? this.interestTags,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
