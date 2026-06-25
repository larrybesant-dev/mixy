import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String hostId;
  final DateTime date;
  final DateTime createdAt;
  final double? latitude;
  final double? longitude;
  final String? venue;
  final String? address;
  final double? radiusKm;

  EventModel({
    required this.id,
    required this.title,
    required this.hostId,
    required this.date,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.venue,
    this.address,
    this.radiusKm,
  });

  factory EventModel.fromDoc(String id, Map<String, dynamic> data) {
    return EventModel(
      id: id,
      title: data['title'] ?? '',
      hostId: data['hostId'] ?? '',
      date: _parseDateTime(data['date']),
      createdAt: _parseDateTime(data['createdAt']),
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      venue: data['venue'] as String?,
      address: data['address'] as String?,
      radiusKm: (data['radiusKm'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'hostId': hostId,
        'date': Timestamp.fromDate(date),
        'createdAt': Timestamp.fromDate(createdAt),
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
        if (venue != null) 'venue': venue,
        if (address != null) 'address': address,
        if (radiusKm != null) 'radiusKm': radiusKm,
      };

  static DateTime _parseDateTime(dynamic value) {
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
}
