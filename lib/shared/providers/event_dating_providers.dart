import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/events/events_service.dart';
// TEMP DISABLED: import '../../services/events/speed_dating_service.dart';
import '../models/event.dart';
// TEMP DISABLED: import '../models/speed_dating.dart';
import 'auth_providers.dart';

/// Event filters model
@immutable
class EventFilters {
  final bool upcomingOnly;
  final bool nearbyOnly;
  final double radiusKm;

  const EventFilters({
    this.upcomingOnly = true,
    this.nearbyOnly = false,
    this.radiusKm = 50.0,
  });

  EventFilters copyWith({
    bool? upcomingOnly,
    bool? nearbyOnly,
    double? radiusKm,
  }) {
    return EventFilters(
      upcomingOnly: upcomingOnly ?? this.upcomingOnly,
      nearbyOnly: nearbyOnly ?? this.nearbyOnly,
      radiusKm: radiusKm ?? this.radiusKm,
    );
  }
}

/// Event filters provider
final eventFiltersProvider =
    NotifierProvider<EventFiltersNotifier, EventFilters>(() {
  return EventFiltersNotifier();
});

class EventFiltersNotifier extends Notifier<EventFilters> {
  @override
  EventFilters build() => const EventFilters();

  void setUpcomingOnly(bool value) {
    state = state.copyWith(upcomingOnly: value);
  }

  void setNearbyOnly(bool value) {
    state = state.copyWith(nearbyOnly: value);
  }

  void setRadiusKm(double value) {
    state = state.copyWith(radiusKm: value);
  }
}

/// Service providers
final eventsServiceProvider = Provider<EventsService>((ref) => EventsService());

// TEMP DISABLED: Speed dating service
// final speedDatingServiceProvider = Provider<SpeedDatingService>((ref) => SpeedDatingService());

/// ============================================================================
/// EVENT PROVIDERS
/// ============================================================================

/// All events stream provider with pagination
final eventsProvider = StreamProvider<List<Event>>((ref) {
  return FirebaseFirestore.instance
      .collection('events')
      .orderBy('startTime', descending: false)
      .limit(30) // Pagination: load next 30 events
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Event.fromMap(doc.data()..['id'] = doc.id))
          .toList())
      .handleError((error) {
    return <Event>[];
  });
});

/// Paginated events with cursor
final paginatedEventsProvider =
    StreamProvider.family<List<Event>, DocumentSnapshot?>(
  (ref, startAfter) {
    var query = FirebaseFirestore.instance
        .collection('events')
        .orderBy('startTime', descending: false)
        .limit(30);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    return query.snapshots().map(
          (snapshot) => snapshot.docs
              .map((doc) => Event.fromMap(doc.data()..['id'] = doc.id))
              .toList(),
        );
  },
);

// NOTE: upcomingEventsProvider moved to events_controller.dart as FutureProvider
// to avoid WebChannel connection issues and provider naming conflicts

/// Past events provider with pagination
final pastEventsProvider = StreamProvider<List<Event>>((ref) {
  final now = Timestamp.fromDate(DateTime.now());
  return FirebaseFirestore.instance
      .collection('events')
      .where('endTime', isLessThan: now)
      .orderBy('endTime', descending: true)
      .limit(20) // Pagination: last 20 past events
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => Event.fromMap(doc.data()..['id'] = doc.id))
          .toList())
      .handleError((error) {
    return <Event>[];
  });
});

/// User's hosted events provider
final hostedEventsProvider = StreamProvider<List<Event>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  final events = ref.watch(eventsProvider).value ?? [];
  yield events.where((event) => event.hostId == currentUser.id).toList();
});

/// User's attending events provider
final attendingEventsProvider = StreamProvider<List<Event>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield [];
    return;
  }

  final events = ref.watch(eventsProvider).value ?? [];
  yield events
      .where((event) => event.attendees.contains(currentUser.id))
      .toList();
});

/// Single event provider
final eventProvider = StreamProvider.family<Event?, String>((ref, eventId) {
  final eventsService = ref.watch(eventsServiceProvider);
  return eventsService.watchEvent(eventId);
});

/// Events controller
final eventsControllerProvider =
    NotifierProvider<EventsController, AsyncValue<Event?>>(() {
  return EventsController();
});

class EventsController extends Notifier<AsyncValue<Event?>> {
  late final EventsService _eventsService;

  @override
  AsyncValue<Event?> build() {
    _eventsService = ref.watch(eventsServiceProvider);
    return const AsyncValue.data(null);
  }

  /// Create a new event
  Future<void> createEvent({
    required String title,
    required String description,
    required DateTime startTime,
    required DateTime endTime,
    required String location,
    required int maxAttendees,
    required String category,
    required double latitude,
    required double longitude,
    String? imageUrl,
    bool isPublic = true,
  }) async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final event = Event(
        id: '',
        title: title,
        description: description,
        hostId: currentUser.id,
        startTime: startTime,
        endTime: endTime,
        location: location,
        attendees: [currentUser.id],
        maxCapacity: maxAttendees,
        category: category,
        latitude: latitude,
        longitude: longitude,
        imageUrl: imageUrl ?? '',
        isPublic: isPublic,
        createdAt: DateTime.now(),
      );

      await _eventsService.createEvent(event);
      state = AsyncValue.data(event);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Update event
  Future<void> updateEvent(String eventId, Event event) async {
    state = const AsyncValue.loading();
    try {
      await _eventsService.updateEvent(event);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Delete event
  Future<void> deleteEvent(String eventId) async {
    state = const AsyncValue.loading();
    try {
      await _eventsService.deleteEvent(eventId);
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Join event
  Future<void> joinEvent(String eventId) async {
    try {
      await _eventsService.rsvpToEvent(eventId, 'going');
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Leave event
  Future<void> leaveEvent(String eventId) async {
    try {
      await _eventsService.removeRsvp(eventId);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Get nearby events (not implemented yet)
  Future<List<Event>> getNearbyEvents(
    double latitude,
    double longitude,
    double radiusKm,
  ) async {
    // TODO: Implement location-based events
    return [];
  }
}

/// Event search controller
final eventSearchControllerProvider =
    NotifierProvider<EventSearchController, AsyncValue<List<Event>>>(() {
  return EventSearchController();
});

class EventSearchController extends Notifier<AsyncValue<List<Event>>> {
  String _searchQuery = '';
  String? _categoryFilter;
  DateTime? _dateFilter;

  @override
  AsyncValue<List<Event>> build() {
    return const AsyncValue.data([]);
  }

  /// Search events
  Future<void> searchEvents(String query) async {
    _searchQuery = query;
    await _performSearch();
  }

  /// Filter by category
  void filterByCategory(String? category) {
    _categoryFilter = category;
    _performSearch();
  }

  /// Filter by date
  void filterByDate(DateTime? date) {
    _dateFilter = date;
    _performSearch();
  }

  /// Clear filters
  void clearFilters() {
    _searchQuery = '';
    _categoryFilter = null;
    _dateFilter = null;
    state = const AsyncValue.data([]);
  }

  Future<void> _performSearch() async {
    state = const AsyncValue.loading();
    try {
      // For now, just return empty list. TODO: Implement proper event search
      var events = <Event>[];

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        events = events.where((event) {
          return event.title
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              event.description
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              event.location.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();
      }

      // Apply category filter
      if (_categoryFilter != null) {
        events =
            events.where((event) => event.category == _categoryFilter).toList();
      }

      // Apply date filter
      if (_dateFilter != null) {
        events = events.where((event) {
          return event.startTime.year == _dateFilter!.year &&
              event.startTime.month == _dateFilter!.month &&
              event.startTime.day == _dateFilter!.day;
        }).toList();
      }

      state = AsyncValue.data(events);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }
}

/// ============================================================================
/// SPEED DATING PROVIDERS
/// ============================================================================

// TEMP DISABLED: Speed dating providers
// final activeSpeedDatingSessionProvider = StreamProvider<SpeedDatingSession?>((ref) async* {
//   final currentUser = ref.watch(currentUserProvider).value;
//   if (currentUser == null) {
//     yield null;
//     return;
//   }
//   await for (final _ in Stream.periodic(const Duration(seconds: 3))) {
//     try {
//       yield null;
//     } catch (e) {
//       yield null;
//     }
//   }
// });

// final speedDatingMatchesProvider = StreamProvider<List<SpeedDatingMatch>>((ref) async* {
//   final currentUser = ref.watch(currentUserProvider).value;
//   if (currentUser == null) {
//     yield [];
//     return;
//   }
//   yield [];
// });

/* DISABLED FOR V1: Speed dating controller references disabled SpeedDatingService methods
/// Speed dating controller
final speedDatingControllerProvider = NotifierProvider<SpeedDatingController, AsyncValue<SpeedDatingRound?>>(() {
  return SpeedDatingController();
});

class SpeedDatingController extends Notifier<AsyncValue<SpeedDatingRound?>> {
  late final SpeedDatingService _speedDatingService;
  StreamSubscription<SpeedDatingRound?>? _sessionSubscription;

  @override
  AsyncValue<SpeedDatingRound?> build() {
    _speedDatingService = ref.watch(speedDatingServiceProvider);
    ref.onDispose(() {
      _sessionSubscription?.cancel();
    });
    return const AsyncValue.data(null);
  }

  /// Join speed dating lobby (find or create session)
  Future<void> joinLobby() async {
    state = const AsyncValue.loading();
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      // Check for existing active session
      final existingSession = await _speedDatingService.findActiveSession(currentUser.id);

      if (existingSession != null) {
        state = AsyncValue.data(existingSession);
        _listenToSession(existingSession.id);
        return;
      }

      // Create new session for waiting users
      final eventId = 'speed_dating_${DateTime.now().millisecondsSinceEpoch}';
      final sessionId = await _speedDatingService.createSession(eventId, [currentUser.id]);
      final session = await _speedDatingService.getSession(sessionId);
      if (session != null) {
        state = AsyncValue.data(session);
        _listenToSession(sessionId);
      }
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Leave lobby/session
  Future<void> leaveLobby() async {
    try {
      _sessionSubscription?.cancel();

      final session = state.value;
      if (session != null) {
        await _speedDatingService.cancelSession(session.id);
      }

      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
    }
  }

  /// Submit decision (like or pass)
  Future<void> submitDecision(bool liked) async {
    try {
      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final session = state.value;
      if (session == null) {
        throw Exception('No active session');
      }

      final decision = liked ? 'like' : 'pass';
      await _speedDatingService.submitDecision(
        session.id,
        currentUser.id,
        decision,
      );
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// Start next round
  Future<void> nextRound() async {
    try {
      final session = state.value;
      if (session == null) {
        throw Exception('No active session');
      }

      await _speedDatingService.startNextRound(session.id);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  /// End session
  Future<void> endSession() async {
    try {
      final session = state.value;
      if (session == null) return;

      await _speedDatingService.endSession(session.id);
      _sessionSubscription?.cancel();
      state = const AsyncValue.data(null);
    } catch (e, stackTrace) {
      state = AsyncValue.error(e, stackTrace);
      rethrow;
    }
  }

  void _listenToSession(String sessionId) {
    _sessionSubscription?.cancel();

    // In production, this would be a Firestore stream
    final stream = Stream.periodic(const Duration(seconds: 2)).asyncMap((_) async {
      return await _speedDatingService.getSession(sessionId);
    });

    _sessionSubscription = (stream).listen(
      (session) {
        state = AsyncValue.data(session);
      },
      onError: (error, stackTrace) {
        state = AsyncValue.error(error, stackTrace);
      },
    );
  }
}
*/

/// Speed dating timer provider
final speedDatingTimerProvider =
    NotifierProvider<SpeedDatingTimerNotifier, Duration>(() {
  return SpeedDatingTimerNotifier();
});

class SpeedDatingTimerNotifier extends Notifier<Duration> {
  Timer? _timer;

  @override
  Duration build() {
    ref.onDispose(() {
      _timer?.cancel();
    });
    return const Duration(minutes: 5);
  }

  /// Start countdown timer
  void startTimer(Duration duration) {
    _timer?.cancel();
    state = duration;

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.inSeconds > 0) {
        state = Duration(seconds: state.inSeconds - 1);
      } else {
        timer.cancel();
      }
    });
  }

  /// Stop timer
  void stopTimer() {
    _timer?.cancel();
    state = const Duration(minutes: 5);
  }

  /// Reset timer
  void resetTimer(Duration duration) {
    _timer?.cancel();
    state = duration;
  }
}

/// Speed dating statistics provider
final speedDatingStatisticsProvider =
    StreamProvider<Map<String, dynamic>>((ref) async* {
  final currentUser = ref.watch(currentUserProvider).value;
  if (currentUser == null) {
    yield {};
    return;
  }

  // Calculate statistics: total sessions, matches, match rate, etc.
  yield {
    'totalSessions': 0,
    'totalMatches': 0,
    'matchRate': 0.0,
    'averageSessionDuration': 0,
  };
});
