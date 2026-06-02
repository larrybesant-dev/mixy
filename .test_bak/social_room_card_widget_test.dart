import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/social/widgets/social_room_card.dart';
import 'package:mixvy/models/room_model.dart';

void main() {
  RoomModel buildRoom({
    String category = 'chill',
    int memberCount = 12,
    List<String> stageUserIds = const ['host-1'],
    List<String> audienceUserIds = const ['u1', 'u2', 'u3'],
  }) {
    return RoomModel(
      id: 'room-1',
      name: 'Velvet After Dark',
      hostId: 'host-1',
      category: category,
      memberCount: memberCount,
      stageUserIds: stageUserIds,
      audienceUserIds: audienceUserIds,
      isLive: true);
  }

  testWidgets('featured social room card shows entry focus cue', (
    tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialRoomCard(room: buildRoom(), featured: true, onTap: () {}))));

    expect(find.text('Start here'), findsOneWidget);
  });

  testWidgets('non featured social room card keeps the focus cue hidden', (
    tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialRoomCard(room: buildRoom(), onTap: () {}))));

    expect(find.text('Start here'), findsNothing);
  });

  testWidgets('compact social room card tells the room story', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SocialRoomCardCompact(
            room: buildRoom(
              category: 'dating',
              stageUserIds: const ['h1', 'h2']),
            onTap: () {}))));

    expect(find.textContaining('Chemistry'), findsOneWidget);
  });
}










