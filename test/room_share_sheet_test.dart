import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/widgets/room_share_sheet.dart';
import 'package:mixvy/models/user_model.dart';

void main() {
  testWidgets('selects friends and sends in-app room invites', (tester) async {
    final invitedFriendIds = <String>[];
    var sharedExternally = false;
    var copiedLink = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: RoomShareSheet(
              roomName: 'Friday Night',
              friends: AsyncValue.data([
                _friend(id: 'friend-1', username: 'Alex'),
                _friend(id: 'friend-2', username: 'Jordan'),
              ]),
              onShareExternally: () async => sharedExternally = true,
              onCopyLink: () async => copiedLink = true,
              onSendInvites: (ids) async => invitedFriendIds.addAll(ids),
              onRetry: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Send to friends on MixVy'), findsOneWidget);
    expect(find.text('Select friends'), findsOneWidget);

    await tester.tap(find.text('Alex'));
    await tester.pump();
    expect(find.text('Send invite (1)'), findsOneWidget);

    await tester.tap(find.text('Share outside MixVy'));
    expect(sharedExternally, isTrue);

    await tester.tap(find.text('Copy room link'));
    expect(copiedLink, isTrue);

    await tester.tap(find.text('Send invite (1)'));
    await tester.pumpAndSettle();
    expect(invitedFriendIds, ['friend-1']);
  });
}

UserModel _friend({required String id, required String username}) {
  return UserModel(
    id: id,
    email: '$id@example.com',
    username: username,
    createdAt: DateTime(2026),
  );
}
