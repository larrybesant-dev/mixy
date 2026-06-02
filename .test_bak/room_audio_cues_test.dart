import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/services/room_audio_cues.dart';

void main() {
  group('RoomAudioCues', () {
    late RoomAudioCues cues;

    setUp(() {
      cues = RoomAudioCues.instance;
    });

    test('is a singleton', () {
      expect(RoomAudioCues.instance, same(RoomAudioCues.instance));
    });

    // On non-web (all test environments), every public cue should be a no-op
    // that completes without throwing.
    group('non-web no-op (test environment is non-web)', () {
      setUp(() {
        // kIsWeb is false in all unit test environments.
        expect(
          kIsWeb,
          isFalse,
          reason: 'These tests assume a non-web environment');
      });

      test('playUserJoined does not throw', () {
        expect(() => cues.playUserJoined(), returnsNormally);
      });

      test('playUserLeft does not throw', () {
        expect(() => cues.playUserLeft(), returnsNormally);
      });

      test('playGiftReceived does not throw', () {
        expect(() => cues.playGiftReceived(), returnsNormally);
      });

      test('playHandRaised does not throw', () {
        expect(() => cues.playHandRaised(), returnsNormally);
      });

      test('playMicApproved does not throw', () {
        expect(() => cues.playMicApproved(), returnsNormally);
      });

      test('dispose does not throw', () {
        expect(() => cues.dispose(), returnsNormally);
      });

      test('methods are callable multiple times without error', () {
        for (var i = 0; i < 5; i++) {
          cues.playUserJoined();
          cues.playUserLeft();
          cues.playGiftReceived();
          cues.playHandRaised();
          cues.playMicApproved();
        }
      });
    });
  });
}










