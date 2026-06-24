import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import '../../shared/models/event.dart';
import '../../shared/models/user_profile.dart';

class EventsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Watch upcoming events (real-time stream)
  Stream<List<Event>> watchUpcomingEvents() {
    try {
      final now = Timestamp.now();
      return _firestore
          .collection('events')
          .where('isPublic', isEqualTo: true)
          .where('startTime', isGreaterThan: now)
          .orderBy('startTime', descending: false)
          .limit(50)
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Event.fromMap(data);
        }).toList();
      }).handleError((error) {
        debugPrint('Error loading upcoming events: $error');
        // Return a stream with empty list on error
        return Stream.value(<Event>[]);
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  /// Watch single event by ID (real-time stream)
  Stream<Event?> watchEvent(String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      final data = snapshot.data()!;
      data['id'] = snapshot.id;
      return Event.fromMap(data);
    });
  }

  /// RSVP to an event with status (going/interested)
  Future<void> rsvpToEvent(String eventId, String status) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    if (status != 'going' && status != 'interested') {
      throw Exception('Invalid RSVP status. Must be "going" or "interested"');
    }

    final batch = _firestore.batch();

    // Add RSVP to event subcollection
    final eventRsvpRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .doc(user.uid);
    batch.set(eventRsvpRef, {
      'userId': user.uid,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Add RSVP to user subcollection
    final userRsvpRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('event_rsvps')
        .doc(eventId);
    batch.set(userRsvpRef, {
      'eventId': eventId,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Update event counters
    final eventRef = _firestore.collection('events').doc(eventId);
    if (status == 'going') {
      batch.update(eventRef, {
        'attendeesCount': FieldValue.increment(1),
      });
    } else if (status == 'interested') {
      batch.update(eventRef, {
        'interestedCount': FieldValue.increment(1),
      });
    }

    await batch.commit();
  }

  /// Remove RSVP from an event
  Future<void> removeRsvp(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    // Get current RSVP status to decrement correct counter
    final rsvpDoc = await _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .doc(user.uid)
        .get();

    if (!rsvpDoc.exists) return;

    final currentStatus = rsvpDoc.data()?['status'] as String?;

    final batch = _firestore.batch();

    // Remove from event subcollection
    final eventRsvpRef = _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .doc(user.uid);
    batch.delete(eventRsvpRef);

    // Remove from user subcollection
    final userRsvpRef = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('event_rsvps')
        .doc(eventId);
    batch.delete(userRsvpRef);

    // Update event counters
    final eventRef = _firestore.collection('events').doc(eventId);
    if (currentStatus == 'going') {
      batch.update(eventRef, {
        'attendeesCount': FieldValue.increment(-1),
      });
    } else if (currentStatus == 'interested') {
      batch.update(eventRef, {
        'interestedCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  /// Watch event attendees by status (real-time stream)
  Stream<List<UserProfile>> watchEventAttendees(String eventId,
      {String? status}) {
    try {
      var query = _firestore
          .collection('events')
          .doc(eventId)
          .collection('attendees')
          .orderBy('updatedAt', descending: true);

      if (status != null) {
        query = query.where('status', isEqualTo: status);
      }

      return query.snapshots().asyncMap((snapshot) async {
        final userIds = snapshot.docs.map((doc) => doc.id).toList();
        if (userIds.isEmpty) return <UserProfile>[];

        final profiles = <UserProfile>[];
        for (final userId in userIds) {
          try {
            final userDoc =
                await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final data = userDoc.data()!;
              data['id'] = userDoc.id;
              profiles.add(UserProfile.fromMap(data));
            }
          } catch (e) {
            continue;
          }
        }
        return profiles;
      });
    } catch (e) {
      return Stream.value([]);
    }
  }

  /// Watch events that friends are attending (real-time stream)
  Stream<List<Event>> watchEventsFriendsAreAttending(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .asyncMap((followingSnapshot) async {
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toList();
      if (followingIds.isEmpty) return <Event>[];

      final now = Timestamp.now();
      final eventsSet = <String, Event>{};

      for (final friendId in followingIds.take(20)) {
        try {
          final friendRsvps = await _firestore
              .collection('users')
              .doc(friendId)
              .collection('event_rsvps')
              .where('status', isEqualTo: 'going')
              .limit(10)
              .get();

          for (final rsvpDoc in friendRsvps.docs) {
            final eventId = rsvpDoc.id;
            if (eventsSet.containsKey(eventId)) continue;

            final eventDoc =
                await _firestore.collection('events').doc(eventId).get();
            if (eventDoc.exists) {
              final eventData = eventDoc.data()!;
              eventData['id'] = eventDoc.id;
              final event = Event.fromMap(eventData);

              if (event.startTime.isAfter(now.toDate())) {
                eventsSet[eventId] = event;
              }
            }
          }
        } catch (e) {
          continue;
        }
      }

      final events = eventsSet.values.toList();
      events.sort((a, b) => a.startTime.compareTo(b.startTime));
      return events;
    }).handleError((error) {
      debugPrint('Error loading friends events: $error');
      return Stream.value(<Event>[]);
    });
  }

  /// Watch recommended events based on user's interests and social graph (real-time stream)
  Stream<List<Event>> watchRecommendedEvents(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .asyncMap((userSnapshot) async {
      if (!userSnapshot.exists) return <Event>[];

      final userData = userSnapshot.data()!;
      final userInterests =
          (userData['interests'] as List<dynamic>?)?.cast<String>() ?? [];

      final now = Timestamp.now();

      try {
        final eventsSnapshot = await _firestore
            .collection('events')
            .where('isPublic', isEqualTo: true)
            .where('startTime', isGreaterThan: now)
            .orderBy('startTime', descending: false)
            .limit(50)
            .get();

        final events = eventsSnapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Event.fromMap(data);
        }).toList();

        final userRsvps = await _firestore
            .collection('users')
            .doc(userId)
            .collection('event_rsvps')
            .get();
        final rsvpedEventIds = userRsvps.docs.map((doc) => doc.id).toSet();

        final recommendedEvents = events.where((event) {
          if (rsvpedEventIds.contains(event.id)) return false;
          if (event.hostId == userId) return false;

          final eventCategory = event.category.toLowerCase();
          final matchesInterest = userInterests.any(
              (interest) => eventCategory.contains(interest.toLowerCase()));

          return matchesInterest || event.attendeesCount > 10;
        }).toList();

        recommendedEvents.sort((a, b) {
          final aScore = _calculateEventScore(a, userInterests);
          final bScore = _calculateEventScore(b, userInterests);
          return bScore.compareTo(aScore);
        });

        return recommendedEvents.take(20).toList();
      } catch (e) {
        return <Event>[];
      }
    }).handleError((error) {
      debugPrint('Error loading recommended events: $error');
      return Stream.value(<Event>[]);
    });
  }

  /// Calculate event recommendation score
  int _calculateEventScore(Event event, List<String> userInterests) {
    int score = 0;

    final eventCategory = event.category.toLowerCase();
    for (final interest in userInterests) {
      if (eventCategory.contains(interest.toLowerCase())) {
        score += 10;
      }
    }

    score += event.attendeesCount;

    if (event.isOnline) {
      score += 5;
    }

    return score;
  }

  /// Get user's RSVP status for an event
  Future<String?> getUserRsvpStatus(String userId, String eventId) async {
    try {
      final doc = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('attendees')
          .doc(userId)
          .get();
      if (!doc.exists) return null;
      return doc.data()?['status'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Stream user's RSVP status for an event
  Stream<String?> watchUserRsvpStatus(String userId, String eventId) {
    return _firestore
        .collection('events')
        .doc(eventId)
        .collection('attendees')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return snapshot.data()?['status'] as String?;
    });
  }

  /// Stream user's event RSVPs
  Stream<List<Event>> watchUserEventRsvps(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('event_rsvps')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final eventIds = snapshot.docs.map((doc) => doc.id).toList();
      if (eventIds.isEmpty) return <Event>[];

      final events = <Event>[];
      for (final eventId in eventIds) {
        try {
          final eventDoc =
              await _firestore.collection('events').doc(eventId).get();
          if (eventDoc.exists) {
            final data = eventDoc.data()!;
            data['id'] = eventDoc.id;
            events.add(Event.fromMap(data));
          }
        } catch (e) {
          continue;
        }
      }
      return events;
    });
  }

  /// Get friends attending an event
  Future<List<UserProfile>> getFriendsAttendingEvent(
      String userId, String eventId) async {
    try {
      final followingSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('following')
          .get();
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toSet();

      final attendeesSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('attendees')
          .where('status', isEqualTo: 'going')
          .get();

      final friendsAttending = <UserProfile>[];
      for (final attendeeDoc in attendeesSnapshot.docs) {
        if (followingIds.contains(attendeeDoc.id)) {
          try {
            final userDoc =
                await _firestore.collection('users').doc(attendeeDoc.id).get();
            if (userDoc.exists) {
              final data = userDoc.data()!;
              data['id'] = userDoc.id;
              friendsAttending.add(UserProfile.fromMap(data));
            }
          } catch (e) {
            continue;
          }
        }
      }
      return friendsAttending;
    } catch (e) {
      return [];
    }
  }

  /// Stream friends attending an event
  Stream<List<UserProfile>> watchFriendsAttendingEvent(
      String userId, String eventId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('following')
        .snapshots()
        .asyncMap((followingSnapshot) async {
      final followingIds = followingSnapshot.docs.map((doc) => doc.id).toSet();
      if (followingIds.isEmpty) return <UserProfile>[];

      final attendeesSnapshot = await _firestore
          .collection('events')
          .doc(eventId)
          .collection('attendees')
          .where('status', isEqualTo: 'going')
          .get();

      final friendsAttending = <UserProfile>[];
      for (final attendeeDoc in attendeesSnapshot.docs) {
        if (followingIds.contains(attendeeDoc.id)) {
          try {
            final userDoc =
                await _firestore.collection('users').doc(attendeeDoc.id).get();
            if (userDoc.exists) {
              final data = userDoc.data()!;
              data['id'] = userDoc.id;
              friendsAttending.add(UserProfile.fromMap(data));
            }
          } catch (e) {
            continue;
          }
        }
      }
      return friendsAttending;
    });
  }

  /// Create a new event
  Future<String> createEvent(Event event) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final docRef = _firestore.collection('events').doc();
    final eventWithId = event.copyWith(id: docRef.id, hostId: user.uid);

    await docRef.set(eventWithId.toMap());
    return docRef.id;
  }

  /// Update an existing event
  Future<void> updateEvent(Event event) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final eventDoc = await _firestore.collection('events').doc(event.id).get();
    if (!eventDoc.exists) throw Exception('Event not found');

    final existingEvent = Event.fromMap(eventDoc.data()!..['id'] = eventDoc.id);
    if (existingEvent.hostId != user.uid) {
      throw Exception('Only the event host can update the event');
    }

    await _firestore.collection('events').doc(event.id).update(event.toMap());
  }

  /// Delete an event
  Future<void> deleteEvent(String eventId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final eventDoc = await _firestore.collection('events').doc(eventId).get();
    if (!eventDoc.exists) throw Exception('Event not found');

    final event = Event.fromMap(eventDoc.data()!..['id'] = eventDoc.id);
    if (event.hostId != user.uid) {
      throw Exception('Only the event host can delete the event');
    }

    await _firestore.collection('events').doc(eventId).delete();
  }
}
