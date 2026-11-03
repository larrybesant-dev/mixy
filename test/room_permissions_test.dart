import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/room_permissions.dart';

void main() {
  group('RoomPermissions.canUseCamera', () {
    test('returns true for each named role', () {
      for (final role in [
        RoomPermissions.host,
        RoomPermissions.cohost,
        RoomPermissions.moderator,
        RoomPermissions.stage,
        RoomPermissions.audience,
      ]) {
        expect(
          RoomPermissions.canUseCamera(role),
          isTrue,
          reason: 'role "$role" should be allowed to use camera',
        );
      }
    });

    test('returns true for arbitrary non-empty role strings', () {
      expect(RoomPermissions.canUseCamera('member'), isTrue);
      expect(RoomPermissions.canUseCamera('guest'), isTrue);
    });

    test('returns false for empty string', () {
      expect(RoomPermissions.canUseCamera(''), isFalse);
    });
  });

  group('RoomPermissions.canUseMic', () {
    test('returns true for host, cohost, moderator, and stage roles', () {
      for (final role in [
        RoomPermissions.host,
        RoomPermissions.cohost,
        RoomPermissions.moderator,
        RoomPermissions.stage,
      ]) {
        expect(
          RoomPermissions.canUseMic(role),
          isTrue,
          reason: 'role "$role" should be allowed to use mic',
        );
      }
    });

    group('RoomPermissions.canBroadcastAudio', () {
      test('allows the mic holder and invited speakers', () {
        const speakerIds = ['mic-holder', 'invited-speaker'];

        expect(
          RoomPermissions.canBroadcastAudio(
            userId: 'mic-holder',
            speakerIds: speakerIds,
          ),
          isTrue,
        );
        expect(
          RoomPermissions.canBroadcastAudio(
            userId: 'invited-speaker',
            speakerIds: speakerIds,
          ),
          isTrue,
        );
      });

      test('rejects audience members who only use camera or chat', () {
        expect(
          RoomPermissions.canBroadcastAudio(
            userId: 'audience-member',
            speakerIds: const ['mic-holder'],
          ),
          isFalse,
        );
      });
    });

    group('RoomPermissions.canTakeOpenMic', () {
      test('allows a signed-in user when nobody holds the mic', () {
        expect(
          RoomPermissions.canTakeOpenMic(
            userId: 'audience-member',
            speakerIds: const [],
          ),
          isTrue,
        );
      });

      test('rejects users when the mic is occupied', () {
        expect(
          RoomPermissions.canTakeOpenMic(
            userId: 'audience-member',
            speakerIds: const ['mic-holder'],
          ),
          isFalse,
        );
      });

      test('rejects an empty user ID', () {
        expect(
          RoomPermissions.canTakeOpenMic(
            userId: '',
            speakerIds: const [],
          ),
          isFalse,
        );
      });
    });

    group('RoomPermissions.canShareAudio', () {
      test('allows an authorized speaker only while their mic is on', () {
        expect(
          RoomPermissions.canShareAudio(
            userId: 'mic-holder',
            speakerIds: const ['mic-holder'],
            isMicEnabled: true,
          ),
          isTrue,
        );
        expect(
          RoomPermissions.canShareAudio(
            userId: 'mic-holder',
            speakerIds: const ['mic-holder'],
            isMicEnabled: false,
          ),
          isFalse,
        );
      });

      test('rejects audience members even if local mic state is stale', () {
        expect(
          RoomPermissions.canShareAudio(
            userId: 'audience-member',
            speakerIds: const ['mic-holder'],
            isMicEnabled: true,
          ),
          isFalse,
        );
      });
    });

    test('returns false for audience and empty roles', () {
      expect(RoomPermissions.canUseMic(RoomPermissions.audience), isFalse);
      expect(RoomPermissions.canUseMic(''), isFalse);
    });
  });

  group('RoomPermissions.canManageParticipant', () {
    const host = 'host-user';

    test('host can manage audience', () {
      expect(
        RoomPermissions.canManageParticipant(
          actorRole: RoomPermissions.host,
          actorUserId: host,
          targetRole: RoomPermissions.audience,
          targetUserId: 'user-a',
          hostUserId: host,
        ),
        isTrue,
      );
    });

    test('host cannot manage themselves', () {
      expect(
        RoomPermissions.canManageParticipant(
          actorRole: RoomPermissions.host,
          actorUserId: host,
          targetRole: RoomPermissions.host,
          targetUserId: host,
          hostUserId: host,
        ),
        isFalse,
      );
    });

    test('audience cannot manage other audience members', () {
      expect(
        RoomPermissions.canManageParticipant(
          actorRole: RoomPermissions.audience,
          actorUserId: 'user-a',
          targetRole: RoomPermissions.audience,
          targetUserId: 'user-b',
          hostUserId: host,
        ),
        isFalse,
      );
    });

    test('moderator cannot manage the host', () {
      expect(
        RoomPermissions.canManageParticipant(
          actorRole: RoomPermissions.moderator,
          actorUserId: 'mod-1',
          targetRole: RoomPermissions.host,
          targetUserId: host,
          hostUserId: host,
        ),
        isFalse,
      );
    });
  });
}
