import 'package:cloud_firestore/cloud_firestore.dart';

class EventModel {
  final String id;
  final String title;
  final String hostId;
  final DateTime date;
  final DateTime createdAt;

  EventModel({
    required this.id,
    required this.title,
    required this.hostId,
    required this.date,
    required this.createdAt,
  });

  factory EventModel.fromDoc(String id, Map<String, dynamic> data) {
    return EventModel(
      id: id,
      title: data['title'] ?? '',
      hostId: data['hostId'] ?? '',
      date: _parseDateTime(data['date']),
      createdAt: _parseDateTime(data['createdAt']),
    );
  }

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
