import 'package:cloud_firestore/cloud_firestore.dart';
export 'event_model.dart';

DateTime _toDateTime(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value) ?? DateTime.now();
  }
  return DateTime.now();
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? bio;
  final List<String> interests;
  final GeoPoint? location;
  final DateTime createdAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.bio,
    this.interests = const [],
    this.location,
    required this.createdAt,
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data =
        (doc.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      interests: List<String>.from(data['interests'] ?? []),
      location: data['location'],
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'photoUrl': photoUrl,
      'bio': bio,
      'interests': interests,
      'location': location,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

class MixEvent {
  final String id;
  final String title;
  final String creatorId;
  final DateTime startTime;
  final List<String> participants;

  MixEvent({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.startTime,
    this.participants = const [],
  });

  factory MixEvent.fromFirestore(DocumentSnapshot doc) {
    final data =
        (doc.data() as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return MixEvent(
      id: doc.id,
      title: data['title'] ?? '',
      creatorId: data['creatorId'] ?? '',
      startTime: _toDateTime(data['startTime']),
      participants: List<String>.from(data['participants'] ?? []),
    );
  }
}



