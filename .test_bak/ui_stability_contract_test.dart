import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/shared/widgets/ui_stability_contract.dart';

void main() {
  group('UI stability contract', () {
    test('HomeLayoutV1 keeps the locked section order', () {
      expect(HomeLayoutV1.sectionTitles, const <String>[
        'Live Pulse',
        'Featured Rooms',
        'Discovery Feed',
      ]);

      expect(
        () => HomeLayoutV1.debugAssertOrder(const <String>[
          HomeLayoutV1.livePulseSlotId,
          HomeLayoutV1.featuredRoomsSlotId,
          HomeLayoutV1.discoveryFeedSlotId,
        ]),
        returnsNormally);
    });

    test('HomeLayoutV1 rejects structural drift', () {
      expect(
        () => HomeLayoutV1.debugAssertOrder(const <String>[
          HomeLayoutV1.livePulseSlotId,
          HomeLayoutV1.discoveryFeedSlotId,
          HomeLayoutV1.featuredRoomsSlotId,
        ]),
        throwsAssertionError);
    });

    test('RoomLayoutV1 keeps the locked section order', () {
      expect(
        () => RoomLayoutV1.debugAssertOrder(const <String>[
          RoomLayoutV1.heroSlotId,
          RoomLayoutV1.quickJoinSlotId,
          RoomLayoutV1.sortControlsSlotId,
          RoomLayoutV1.roomCardsSlotId,
        ]),
        returnsNormally);
    });

    test('RoomLayoutV1 rejects structural drift', () {
      expect(
        () => RoomLayoutV1.debugAssertOrder(const <String>[
          RoomLayoutV1.heroSlotId,
          RoomLayoutV1.sortControlsSlotId,
          RoomLayoutV1.quickJoinSlotId,
          RoomLayoutV1.roomCardsSlotId,
        ]),
        throwsAssertionError);
    });
  });
}










