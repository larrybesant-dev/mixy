import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/widgets/live_room_media_action_strip.dart';

void main() {
  group('shouldTrackMicLevel', () {
    test('returns true only when call is ready and mic is live', () {
      expect(shouldTrackMicLevel(isCallReady: true, isMicMuted: false), isTrue);

      expect(
        shouldTrackMicLevel(isCallReady: false, isMicMuted: false),
        isFalse,
      );

      expect(shouldTrackMicLevel(isCallReady: true, isMicMuted: true), isFalse);
    });
  });
}



