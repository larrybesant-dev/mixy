import 'package:mixvy/models/room_model.dart';
import 'package:mixvy/models/social_activity_model.dart';
import 'package:mixvy/models/user_model.dart';

class PulseFeedItem {
  const PulseFeedItem({
    required this.id,
    required this.type,
    required this.title,
    required this.detail,
    required this.timestamp,
  });

  final String id;
  final String type;
  final String title;
  final String detail;
  final DateTime timestamp;

  bool get isQuietState => type == 'quiet_state';
}

class HomeFeedSnapshot {
  const HomeFeedSnapshot({
    this.activities = const <SocialActivity>[],
    this.liveRooms = const <RoomModel>[],
    this.suggestedUsers = const <UserModel>[],
    this.pulseItems = const <PulseFeedItem>[],
  });

  final List<SocialActivity> activities;
  final List<RoomModel> liveRooms;
  final List<UserModel> suggestedUsers;
  final List<PulseFeedItem> pulseItems;

  bool get hasMomentum => pulseItems.any((item) => !item.isQuietState);

  String get headline {
    if (hasMomentum) {
      return 'Your people are moving right now';
    }
    if (liveRooms.isNotEmpty) {
      return '${liveRooms.length} rooms are live right now';
    }
    if (suggestedUsers.isNotEmpty) {
      return 'Fresh connections are waiting';
    }
    return 'Your circle is quiet right now.';
  }

  String get subheadline {
    if (hasMomentum) {
      return 'Jump back in while the room energy is still warm.';
    }
    if (liveRooms.isNotEmpty) {
      return 'Join a live room or discover someone new tonight.';
    }
    if (suggestedUsers.isNotEmpty) {
      return 'Explore new profiles and build your circle.';
    }
    return 'Start the vibe and give people something to join.';
  }
}
