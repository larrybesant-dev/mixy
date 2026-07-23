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
