import '../../../core/events/app_event.dart';
import '../models/home_feed_snapshot.dart';
import '../../../models/room_model.dart';
import '../../../models/social_activity_model.dart';
import '../../../models/user_model.dart';

class HomeFeedService {
  const HomeFeedService();

  void handle(AppEvent event) {
    // Feed and pulse are derived projections only.
    // Persistence and fan-out happen in the event pipeline.
  }

  HomeFeedSnapshot buildSnapshot({
    required List<SocialActivity> activities,
    required List<RoomModel> liveRooms,
    required List<UserModel> suggestedUsers,
  }) {
    final roomSignals = <String, _RoomSignal>{};
    final pulseItems = <PulseFeedItem>[];

    final sortedActivities = [...activities]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final activity in sortedActivities) {
      if (_isRoomScopedActivity(activity)) {
        final key = _roomKeyFromActivity(activity);
        if (key.isNotEmpty) {
          roomSignals
              .putIfAbsent(key, () => _RoomSignal(key: key))
              .applyActivity(activity);
          continue;
        }
      }

      pulseItems.add(
        PulseFeedItem(
          id: 'activity:${activity.id}',
          type: activity.type,
          title: _titleForActivity(activity),
          detail: activity.value,
          timestamp: activity.timestamp,
        ),
      );
    }

    for (final room in liveRooms) {
      final key = 'room:${room.id}';
      roomSignals.putIfAbsent(key, () => _RoomSignal(key: key)).applyRoom(room);
    }

    pulseItems.addAll(roomSignals.values.map((signal) => signal.toPulseItem()));

    final rankedItems = _rankAndDedupe(pulseItems);

    return HomeFeedSnapshot(
      activities: List<SocialActivity>.unmodifiable(sortedActivities),
      liveRooms: List<RoomModel>.unmodifiable(liveRooms),
      suggestedUsers: List<UserModel>.unmodifiable(suggestedUsers),
      pulseItems: rankedItems,
    );
  }

  String _titleForActivity(SocialActivity activity) {
    switch (activity.type) {
      case 'followed_user':
        return 'New connection made';
      case 'updated_profile':
        return 'Profile refresh';
      case 'joined_room':
        return 'Someone joined a room';
      case 'went_live':
        return 'New live energy';
      default:
        return 'Fresh activity in your circle';
    }
  }

  bool _isRoomScopedActivity(SocialActivity activity) {
    switch (activity.type) {
      case 'joined_room':
      case 'left_room':
      case 'went_live':
        return true;
      default:
        return false;
    }
  }

  String _roomKeyFromActivity(SocialActivity activity) {
    final targetId = (activity.targetId ?? '').trim();
    if (targetId.isNotEmpty) {
      return 'room:$targetId';
    }

    final roomName = (activity.metadata['roomName'] as String? ?? '').trim();
    if (roomName.isNotEmpty) {
      return 'room-name:${roomName.toLowerCase()}';
    }

    return '';
  }

  List<PulseFeedItem> _rankAndDedupe(List<PulseFeedItem> rawItems) {
    if (rawItems.isEmpty) {
      return _seededPulseItems();
    }

    final seen = <String>{};
    final uniqueItems = <PulseFeedItem>[];
    final ranked = [...rawItems]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final item in ranked) {
      final dedupeKey =
          '${item.type}|${item.title}|${item.detail}'.toLowerCase();
      if (seen.add(dedupeKey)) {
        uniqueItems.add(item);
      }
    }

    return List<PulseFeedItem>.unmodifiable(uniqueItems.take(3));
  }

  List<PulseFeedItem> _seededPulseItems() {
    final now = DateTime.now();
    return List<PulseFeedItem>.unmodifiable(<PulseFeedItem>[
      PulseFeedItem(
        id: 'seed:nearby-vibe',
        type: 'system_trending',
        title: '3 people started a vibe nearby',
        detail: 'Tap in and meet people while rooms are warming up.',
        timestamp: now.subtract(const Duration(minutes: 1)),
      ),
      PulseFeedItem(
        id: 'seed:music-trending',
        type: 'system_trending',
        title: 'New rooms trending in Music',
        detail: 'Jump into the latest rooms and find your energy.',
        timestamp: now.subtract(const Duration(minutes: 3)),
      ),
      PulseFeedItem(
        id: 'seed:new-join',
        type: 'system_trending',
        title: 'Someone just joined MixVy',
        detail: 'Say hi and help set the tone for tonight.',
        timestamp: now.subtract(const Duration(minutes: 5)),
      ),
    ]);
  }
}

class _RoomSignal {
  _RoomSignal({required this.key});

  final String key;
  String roomName = 'Live room';
  int liveMemberCount = 0;
  int onMicCount = 0;
  int activityCount = 0;
  bool isLive = false;
  DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(0);

  void applyActivity(SocialActivity activity) {
    activityCount += 1;
    if (activity.timestamp.isAfter(timestamp)) {
      timestamp = activity.timestamp;
    }
    final resolvedRoomName =
        (activity.metadata['roomName'] as String? ?? '').trim();
    if (resolvedRoomName.isNotEmpty) {
      roomName = resolvedRoomName;
    } else if ((activity.targetId ?? '').trim().isNotEmpty &&
        roomName == 'Live room') {
      roomName = activity.targetId!.trim();
    }
    if (activity.type == 'went_live') {
      isLive = true;
    }
  }

  void applyRoom(RoomModel room) {
    roomName = room.name.trim().isEmpty ? roomName : room.name.trim();
    liveMemberCount =
        room.memberCount > liveMemberCount ? room.memberCount : liveMemberCount;
    onMicCount = room.stageUserIds.length > onMicCount
        ? room.stageUserIds.length
        : onMicCount;
    isLive = isLive || room.isLive;
    final roomTimestamp = room.updatedAt?.toDate() ?? room.createdAt?.toDate();
    if (roomTimestamp != null && roomTimestamp.isAfter(timestamp)) {
      timestamp = roomTimestamp;
    }
  }

  bool _isRawDocumentId(String name) {
    // Firestore Document IDs are typically 20 characters long and alphanumeric.
    final idRegex = RegExp(r'^[a-zA-Z0-9]{20}$');
    return idRegex.hasMatch(name.trim());
  }

  PulseFeedItem toPulseItem() {
    final intensity =
        liveMemberCount >= 8 || onMicCount >= 2 || activityCount >= 2;

    String finalRoomName = roomName;
    if (finalRoomName == 'Live room' || _isRawDocumentId(finalRoomName)) {
      finalRoomName = 'Summer Blast Gathering';
    }

    final detail = onMicCount > 0
        ? '$liveMemberCount inside • $onMicCount on mic'
        : liveMemberCount > 0
            ? '$liveMemberCount inside now'
            : 'Fresh room movement happening now';

    return PulseFeedItem(
      id: key,
      type: 'room_momentum',
      title: '$finalRoomName is ${intensity ? 'hot' : 'active'} right now',
      detail: detail,
      timestamp: timestamp,
    );
  }
}
