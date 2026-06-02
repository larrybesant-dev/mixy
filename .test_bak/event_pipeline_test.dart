import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/core/events/app_event.dart';
import 'package:mixvy/core/events/app_event_bus.dart';
import 'package:mixvy/core/events/event_inspector.dart';
import 'package:mixvy/core/events/event_pipeline.dart';
import 'package:mixvy/services/notification_service.dart';
import 'package:mixvy/services/social_activity_service.dart';

void main() {
  group('EventPipeline', () {
    late FakeFirebaseFirestore firestore;
    late SocialActivityService socialActivityService;
    late NotificationService notificationService;
    late AppEventBus eventBus;
    late EventPipeline pipeline;

    setUp(() {
      AppEventInspector.instance.clear();
      firestore = FakeFirebaseFirestore();
      socialActivityService = SocialActivityService();
      notificationService = NotificationService();
      eventBus = AppEventBus.testInstance();
      pipeline = EventPipeline(
        eventBus: eventBus,
        socialActivityService: socialActivityService,
        notificationService: notificationService)..start();
    });

    tearDown(() async {
      await pipeline.dispose();
      await eventBus.dispose();
    });

    test('routes follow events into activity feed and notifications', () async {
      eventBus.emit(
        FollowEvent(
          id: 'evt-follow-1',
          timestamp: DateTime(2026, 4, 14, 23, 0),
          fromUserId: 'alice',
          toUserId: 'bob',
          fromUsername: 'Alice Noir',
          toUsername: 'Bob Gold'));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final activityDocs = await firestore.collection('activity_feed').get();
      final notificationDocs = await firestore
          .collection('notifications')
          .get();

      expect(activityDocs.docs, hasLength(1));
      expect(activityDocs.docs.first.data()['type'], 'followed_user');
      expect(activityDocs.docs.first.data()['userId'], 'alice');

      expect(notificationDocs.docs, hasLength(1));
      expect(notificationDocs.docs.first.data()['userId'], 'bob');
      expect(notificationDocs.docs.first.data()['type'], 'follow');

      final latest = AppEventInspector.instance.latest;
      expect(latest, isNotNull);
      expect(latest!.eventType, 'FollowEvent');
      expect(latest.sessionId, 'social:alice');
      expect(latest.correlationId, 'follow:alice:bob');
      expect(latest.tags, contains('social'));
      expect(
        latest.consumerTraces.where((trace) => trace.status == 'success'),
        hasLength(3));
    });

    test(
      'routes profile updates into activity feed without duplicate notifications',
      () async {
        eventBus.emit(
          ProfileUpdatedEvent(
            id: 'evt-profile-1',
            timestamp: DateTime(2026, 4, 14, 23, 5),
            userId: 'curve'));

        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final activityDocs = await firestore.collection('activity_feed').get();
        final notificationDocs = await firestore
            .collection('notifications')
            .get();

        expect(activityDocs.docs, hasLength(1));
        expect(activityDocs.docs.first.data()['type'], 'updated_profile');
        expect(notificationDocs.docs, isEmpty);
      });

    test('captures shared session flow for room lifecycle events', () async {
      const sessionId = 'room:velvet:alice';
      const correlationId = 'room-flow:velvet:alice';

      eventBus.emit(
        RoomJoinedEvent(
          id: 'evt-room-join-1',
          timestamp: DateTime(2026, 4, 14, 23, 10),
          sessionId: sessionId,
          correlationId: correlationId,
          userId: 'alice',
          roomId: 'velvet'));
      eventBus.emit(
        MicStateChangedEvent(
          id: 'evt-room-mic-1',
          timestamp: DateTime(2026, 4, 14, 23, 11),
          sessionId: sessionId,
          correlationId: correlationId,
          userId: 'alice',
          roomId: 'velvet',
          isSpeaker: true));

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final sessionEntries = AppEventInspector.instance.entries
          .where((entry) => entry.sessionId == sessionId)
          .toList(growable: false);

      expect(sessionEntries, hasLength(2));
      expect(
        sessionEntries.every((entry) => entry.correlationId == correlationId),
        isTrue);
    });

    test('ignores duplicated event ids to prevent double fan-out', () async {
      final event = FollowEvent(
        id: 'evt-dup-1',
        timestamp: DateTime(2026, 4, 14, 23, 15),
        sessionId: 'social:ivy',
        correlationId: 'follow:ivy:nova',
        fromUserId: 'ivy',
        toUserId: 'nova',
        fromUsername: 'Ivy',
        toUsername: 'Nova');

      eventBus.emit(event);
      eventBus.emit(event);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final activityDocs = await firestore.collection('activity_feed').get();
      final notificationDocs = await firestore
          .collection('notifications')
          .get();

      expect(activityDocs.docs, hasLength(1));
      expect(notificationDocs.docs, hasLength(1));

      final droppedEntries = AppEventInspector.instance.entries
          .where((entry) => entry.eventId == 'evt-dup-1' && entry.dropped)
          .toList(growable: false);
      expect(droppedEntries, isNotEmpty);
    });
  });
}










