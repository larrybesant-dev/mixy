import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/widgets/user_list_panel.dart';
import 'package:mixvy/models/room_participant_model.dart';

void main() {
  test('queued camera user is shown in the mic queue while mic is off', () {
    final participant = RoomParticipantModel(
      userId: 'curve-user',
      role: 'audience',
      camOn: true,
      micOn: false,
      joinedAt: DateTime(2026, 1, 1),
      lastActiveAt: DateTime(2026, 1, 1),
    );

    expect(
      classifyRoomRosterParticipant(
        participant: participant,
        micQueueUserIds: const {'curve-user'},
      ),
      RoomRosterSection.micQueue,
    );
  });

  test('active mic takes priority over a stale queue request', () {
    final participant = RoomParticipantModel(
      userId: 'curve-user',
      role: 'audience',
      camOn: true,
      micOn: true,
      joinedAt: DateTime(2026, 1, 1),
      lastActiveAt: DateTime(2026, 1, 1),
    );

    expect(
      classifyRoomRosterParticipant(
        participant: participant,
        micQueueUserIds: const {'curve-user'},
      ),
      RoomRosterSection.onCam,
    );
  });

  testWidgets('hovering another user shows personal room actions', (
    tester,
  ) async {
    RoomParticipantModel? whisperedUser;
    final participant = RoomParticipantModel(
      userId: 'curve-user',
      role: 'audience',
      displayName: 'Curve',
      joinedAt: DateTime(2026, 1, 1),
      lastActiveAt: DateTime(2026, 1, 1),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Material(
          child: SizedBox(
            width: 300,
            height: 300,
            child: UserListPanel(
              participants: [participant],
              currentUserId: 'current-user',
              presenceList: const [],
              displayNameById: const {'curve-user': 'Curve'},
              avatarUrlById: const {},
              onWhisper: (user) => whisperedUser = user,
              onGift: (_) {},
              onSendMoney: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Whisper'), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(tester.getCenter(find.text('Curve')));
    await tester.pump();

    expect(find.byTooltip('Whisper'), findsOneWidget);
    expect(find.byTooltip('Send Gift'), findsOneWidget);
    expect(find.byTooltip('Send Money'), findsOneWidget);

    await tester.tap(find.byTooltip('Whisper'));
    expect(whisperedUser?.userId, 'curve-user');
  });
}
