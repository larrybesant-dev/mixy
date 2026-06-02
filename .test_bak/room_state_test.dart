import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/controllers/room_state.dart';

void main() {
  test('RoomState enforces deterministic speaker and chat helpers', () {
    const state = RoomState(
      roomId: 'room-a',
      hostId: 'host-1',
      userIds: <String>['host-1', 'user-1', 'user-2', 'user-3'],
      speakerIds: <String>['host-1', 'user-1', 'user-2', 'user-3']);

    expect(state.canChat('user-1'), isTrue);
    expect(state.canChat('user-99'), isFalse);
    expect(state.isSpeaker('host-1'), isTrue);
    expect(state.canAddSpeaker('user-4'), isFalse);
  });

  test(
    'RoomState camera viewer helpers are driven only by camViewersByUser',
    () {
      const state = RoomState(
        roomId: 'room-a',
        currentUserId: 'me',
        userIds: <String>['me', 'john', 'sarah'],
        camViewersByUser: <String, List<String>>{
          'me': <String>['john'],
          'sarah': <String>['me'],
        });

      expect(state.isWatchingMe(myUserId: 'me', otherUserId: 'john'), isTrue);
      expect(state.isWatchingMe(myUserId: 'me', otherUserId: 'sarah'), isFalse);
      expect(
        state.canViewCamera(targetUserId: 'sarah', viewerUserId: 'me'),
        isTrue);
      expect(state.viewerCountFor('me'), 1);
    });

  test('RoomState authority helpers only allow staff to manage the room', () {
    const state = RoomState(
      roomId: 'room-b',
      hostId: 'host-1',
      participantRolesByUser: <String, String>{
        'host-1': 'host',
        'cohost-1': 'cohost',
        'mod-1': 'moderator',
        'guest-1': 'audience',
      });

    expect(state.canManageStage('host-1'), isTrue);
    expect(state.canManageStage('cohost-1'), isTrue);
    expect(state.canManageStage('mod-1'), isFalse);
    expect(state.canModerate('mod-1'), isTrue);
    expect(state.canManageStage('guest-1'), isFalse);
  });

  test(
    'role contract stays deterministic across owner host and fallback cases',
    () {
      const state = RoomState(
        roomId: 'room-b',
        hostId: 'host-1',
        participantRolesByUser: <String, String>{'cohost-1': 'cohost'},
        sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
          'owner-1': RoomSessionSnapshot(
            userId: 'owner-1',
            displayName: 'Owner',
            role: 'owner'),
          'guest-1': RoomSessionSnapshot(
            userId: 'guest-1',
            displayName: 'Guest',
            role: 'mystery-role'),
        });

      expect(state.roleFor('host-1'), roomRoleHost);
      expect(state.roleFor('owner-1'), roomRoleOwner);
      expect(state.roleFor('cohost-1'), roomRoleCohost);
      expect(state.roleFor('guest-1'), roomRoleAudience);
      expect(canManageStageRole(roomRoleOwner), isTrue);
      expect(canModerateRole(roomRoleModerator), isTrue);
      expect(canUseMicRole(roomRoleStage), isTrue);
    });

  test('RoomState only renders users after their join snapshot is stable', () {
    const state = RoomState(
      roomId: 'room-c',
      userIds: <String>['host-1', 'user-1'],
      stableUserIds: <String>['host-1'],
      pendingUserIds: <String>{'user-1'},
      sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
        'host-1': RoomSessionSnapshot(
          userId: 'host-1',
          displayName: 'HostOne',
          role: 'host'),
        'user-1': RoomSessionSnapshot(
          userId: 'user-1',
          displayName: 'VelvetHandle',
          role: 'audience'),
      });

    expect(state.shouldRenderUser('host-1'), isTrue);
    expect(state.shouldRenderUser('user-1'), isFalse);
    expect(state.displayNameFor('host-1'), 'HostOne');
    expect(state.displayNameFor('user-1'), 'VelvetHandle');
  });

  test(
    'RoomState presentation role and on-mic authority come from one path',
    () {
      const state = RoomState(
        roomId: 'room-present',
        currentUserId: 'host-1',
        hostId: 'host-1',
        userIds: <String>['host-1', 'cohost-1', 'stage-1', 'audience-1'],
        stableUserIds: <String>['host-1', 'cohost-1', 'stage-1', 'audience-1'],
        speakerIds: <String>['host-1', 'stage-1'],
        participantRolesByUser: <String, String>{
          'host-1': 'host',
          'cohost-1': 'cohost',
          'stage-1': 'stage',
          'audience-1': 'audience',
        });

      expect(state.presentationRoleFor('host-1'), roomRoleHost);
      expect(state.presentationRoleFor('cohost-1'), roomRoleCohost);
      expect(state.presentationRoleFor('stage-1'), roomRoleStage);
      expect(state.presentationRoleFor('audience-1'), roomRoleAudience);
      expect(state.isOnMicByAuthority('host-1'), isTrue);
      expect(state.isOnMicByAuthority('cohost-1'), isTrue);
      expect(state.isOnMicByAuthority('stage-1'), isTrue);
      expect(state.isOnMicByAuthority('audience-1'), isFalse);
    });

  test('RoomState lifecycle resolves deterministically by sync condition', () {
    const hydratingState = RoomState(
      roomId: 'room-life',
      phase: LiveRoomPhase.joining,
      currentUserId: 'host-1',
      sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
        'host-1': RoomSessionSnapshot(
          userId: 'host-1',
          displayName: 'Host',
          role: 'host'),
      });

    const activeState = RoomState(
      roomId: 'room-life',
      phase: LiveRoomPhase.joined,
      currentUserId: 'host-1',
      hostId: 'host-1',
      stableUserIds: <String>['host-1'],
      sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
        'host-1': RoomSessionSnapshot(
          userId: 'host-1',
          displayName: 'Host',
          role: 'host'),
      });

    const degradedState = RoomState(
      roomId: 'room-life',
      phase: LiveRoomPhase.joined,
      currentUserId: 'host-1',
      hostId: 'host-1',
      errormessage: 'Room state is reconnecting.',
      sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
        'host-1': RoomSessionSnapshot(
          userId: 'host-1',
          displayName: 'Host',
          role: 'host'),
      });

    expect(hydratingState.lifecycleState, RoomLifecycleState.hydrating);
    expect(activeState.lifecycleState, RoomLifecycleState.active);
    expect(degradedState.lifecycleState, RoomLifecycleState.degraded);
    expect(
      activeState.canExecute(RoomAction.manageStage, userId: 'host-1'),
      isTrue);
    expect(
      hydratingState.canExecute(RoomAction.manageStage, userId: 'host-1'),
      isFalse);
  });

  test(
    'RoomState blocks current-user authority until hydration is resolved',
    () {
      const pendingAudienceState = RoomState(
        roomId: 'room-d',
        currentUserId: 'user-1',
        pendingUserIds: <String>{'user-1'},
        sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
          'user-1': RoomSessionSnapshot(
            userId: 'user-1',
            displayName: 'Late Joiner',
            role: 'audience'),
        });

      const hydratedHostState = RoomState(
        roomId: 'room-d',
        currentUserId: 'host-1',
        hostId: 'host-1',
        pendingUserIds: <String>{'host-1'},
        sessionSnapshotsByUser: <String, RoomSessionSnapshot>{
          'host-1': RoomSessionSnapshot(
            userId: 'host-1',
            displayName: 'Host One',
            role: 'host'),
        });

      expect(pendingAudienceState.isRoomFullyHydrated, isFalse);
      expect(pendingAudienceState.canManageStage('user-1'), isFalse);

      expect(hydratedHostState.isRoomFullyHydrated, isTrue);
      expect(hydratedHostState.canManageStage('host-1'), isTrue);
    });
}










