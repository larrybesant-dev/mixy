import 'package:flutter/foundation.dart';

class UiStabilityContract {
  const UiStabilityContract._();

  static void debugAssertOrder({
    required String contractName,
    required List<String> expected,
    required List<String> actual,
  }) {
    assert(
      listEquals(expected, actual),
      '$contractName violated. Expected ${expected.join(' -> ')} but got ${actual.join(' -> ')}. Bump the layout contract version before changing the screen skeleton.',
    );
  }
}

class HomeLayoutV1 {
  const HomeLayoutV1._();

  static const String version = 'v1';

  static const String livePulseSlotId = 'live_pulse';
  static const String featuredRoomsSlotId = 'featured_rooms';
  static const String discoveryFeedSlotId = 'discovery_feed';

  static const List<String> orderedSlotIds = <String>[
    livePulseSlotId,
    featuredRoomsSlotId,
    discoveryFeedSlotId,
  ];

  static const List<String> sectionTitles = <String>[
    'Live Pulse',
    'Featured Rooms',
    'Discovery Feed',
  ];

  static const Key livePulseKey = ValueKey<String>('home-layout-v1/live-pulse');
  static const Key featuredRoomsKey = ValueKey<String>(
    'home-layout-v1/featured-rooms',
  );
  static const Key discoveryFeedKey = ValueKey<String>(
    'home-layout-v1/discovery-feed',
  );

  static void debugAssertOrder(List<String> actual) {
    UiStabilityContract.debugAssertOrder(
      contractName: 'HomeLayoutV1',
      expected: orderedSlotIds,
      actual: actual,
    );
  }
}

class RoomLayoutV1 {
  const RoomLayoutV1._();

  static const String version = 'v1';

  static const String heroSlotId = 'hero_entry';
  static const String quickJoinSlotId = 'quick_join';
  static const String sortControlsSlotId = 'sort_controls';
  static const String roomCardsSlotId = 'room_cards';

  static const List<String> orderedSlotIds = <String>[
    heroSlotId,
    quickJoinSlotId,
    sortControlsSlotId,
    roomCardsSlotId,
  ];

  static const Key heroKey = ValueKey<String>('rooms-layout-v1/hero');
  static const Key quickJoinKey = ValueKey<String>(
    'rooms-layout-v1/quick-join',
  );
  static const Key sortControlsKey = ValueKey<String>(
    'rooms-layout-v1/sort-controls',
  );
  static const Key roomCardsKey = ValueKey<String>(
    'rooms-layout-v1/room-cards',
  );

  static void debugAssertOrder(List<String> actual) {
    UiStabilityContract.debugAssertOrder(
      contractName: 'RoomLayoutV1',
      expected: orderedSlotIds,
      actual: actual,
    );
  }
}



