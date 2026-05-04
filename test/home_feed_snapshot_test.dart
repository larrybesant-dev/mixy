import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/feed/services/home_feed_service.dart';
import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/models/social_activity_model.dart';
import 'package:mixvy/models/user_model.dart';

void main() {
  test(
    'buildSnapshot deduplicates overlapping room events into one pulse item',
    () {
      final snapshot = const HomeFeedService().buildSnapshot(
        activities: [
          SocialActivity(
            id: 'a1',
            userId: 'u1',
            type: 'joined_room',
            targetId: 'room-1',
            timestamp: DateTime(2026, 4, 14, 22, 10),
            metadata: {'roomName': 'Velvet Lounge'},
          ),
          SocialActivity(
            id: 'a2',
            userId: 'u2',
            type: 'went_live',
            targetId: 'room-1',
            timestamp: DateTime(2026, 4, 14, 22, 12),
            metadata: {'roomName': 'Velvet Lounge'},
          ),
          SocialActivity(
            id: 'a3',
            userId: 'u3',
            type: 'followed_user',
            targetId: 'u9',
            timestamp: DateTime(2026, 4, 14, 22, 14),
            metadata: {'targetUsername': '@midnightmuse'},
          ),
        ],
        liveRooms: [
          RoomModel(
            id: 'room-1',
            name: 'Velvet Lounge',
            hostId: 'host-1',
            isLive: true,
            memberCount: 12,
            stageUserIds: const ['host-1', 'u2'],
            audienceUserIds: const ['u1'],
            createdAt: Timestamp.fromDate(DateTime(2026, 4, 14, 21, 55)),
          ),
        ],
        suggestedUsers: [
          UserModel(
            id: 's1',
            email: 'test@example.com',
            username: 'velvetstar',
            createdAt: DateTime(2026, 4, 1),
          ),
        ],
      );

      expect(snapshot.pulseItems.length, 2);
      expect(
        snapshot.pulseItems.first.title,
        'Fresh activity from your circle',
      );
      expect(snapshot.pulseItems[1].title, 'Velvet Lounge is hot right now');
      expect(snapshot.pulseItems[1].detail, '12 inside • 2 on mic');
    },
  );

  test(
    'buildSnapshot creates a quiet-state pulse when there are no events',
    () {
      final snapshot = const HomeFeedService().buildSnapshot(
        activities: const [],
        liveRooms: const [],
        suggestedUsers: const [],
      );

      // When the graph is empty the feed is seeded with 3 onboarding-safe
      // system items so the Social Pulse never renders an empty state.
      expect(snapshot.pulseItems.length, 3);
      expect(snapshot.pulseItems.every((i) => i.type == 'system_trending'), isTrue);
    },
  );
}
