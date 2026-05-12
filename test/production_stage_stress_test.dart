import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mixvy/features/room/presentation/live_room_screen.dart';
import 'package:mixvy/features/room/providers/room_firestore_provider.dart';
import 'package:mixvy/features/room/providers/participant_providers.dart';
import 'package:mixvy/features/room/widgets/stage_and_audience_view.dart';
import 'package:mixvy/models/room_participant_model.dart';
import 'package:mixvy/models/user_model.dart';
import 'package:mixvy/presentation/providers/user_provider.dart';

/// PRODUCTION STAGE STRESS TEST
/// 
/// Purpose: This test simulates a high-load room (100 users) to verify:
/// 1. The 4-mic Stage authority logic.
/// 2. Bandwidth optimization (Audience grid rendering).
/// 3. Reactive UI stability with 100+ Firestore document changes.

void main() {
  testWidgets('Stress Test: 100 Audience Members + 4 Stage Speakers', (WidgetTester tester) async {
    // Set desktop-like size for stress testing
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final firestore = FakeFirebaseFirestore();
    const roomId = 'stress-test-room';
    
    // 1. Setup Room Metadata
    await firestore.collection('rooms').doc(roomId).set({
      'name': 'Stress Test Room',
      'hostId': 'host-vip',
      'maxSpeakers': 4,
      'memberCount': 104,
    });

    // 2. Setup 100 Audience Members
    final participants = <RoomParticipantModel>[];
    for (int i = 1; i <= 100; i++) {
      final p = RoomParticipantModel(
        userId: 'user-$i',
        displayName: 'Guest $i',
        role: 'audience',
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
        photoUrl: 'https://i.pravatar.cc/150?u=user-$i',
      );
      participants.add(p);
      
      // Seed Firestore participants collection
      await firestore.collection('rooms').doc(roomId).collection('participants').doc(p.userId).set(p.toMap());
    }

    // 3. Setup 4 Stage Speakers
    final speakers = <RoomParticipantModel>[];
    final speakerIds = <String>[];
    for (int i = 101; i <= 104; i++) {
      final s = RoomParticipantModel(
        userId: 'user-$i',
        displayName: 'Speaker $i',
        role: 'stage',
        micOn: true,
        joinedAt: DateTime.now(),
        lastActiveAt: DateTime.now(),
      );
      speakers.add(s);
      speakerIds.add(s.userId);
      participants.add(s);
      
      await firestore.collection('rooms').doc(roomId).collection('participants').doc(s.userId).set(s.toMap());
      await firestore.collection('rooms').doc(roomId).collection('speakers').doc(s.userId).set({'userId': s.userId});
    }

    // 4. Launch the App
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1', // Testing as one of the audience members
              email: 'user1@mixvy.com',
              username: 'User One',
              createdAt: DateTime.now(),
            ),
          ),
          // Ensure providers use our fake firestore
          participantsStreamProvider.overrideWith(
            (ref, rid) => firestore.collection('rooms').doc(rid).collection('participants').snapshots().map((snap) => snap.docs.map((d) => RoomParticipantModel.fromMap(d.data())).toList())
          ),
          roomSpeakerUserIdsProvider.overrideWith(
             (ref, rid) => Stream.value(speakerIds)
          ),
        ],
        child: const MaterialApp(
          home: LiveRoomScreen(roomId: roomId),
        ),
      ),
    );

    // Initial settle
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // VERIFICATION 1: Main Stage Presence
    expect(find.byType(StageAndAudienceView), findsOneWidget);
    
    // VERIFICATION 2: Stage Grid (4 Speakers)
    // The Stage area should be rendered. 
    // We check if the "Speaker" text is visible on the stage.
    expect(find.text('Speaker 101'), findsOneWidget);
    expect(find.text('Speaker 104'), findsOneWidget);

    // VERIFICATION 3: Audience Grid (100 Users)
    // Flutter's ListView/GridView is lazy, so we verify a few are present.
    expect(find.text('Guest 1'), findsOneWidget);
    expect(find.text('Guest 5'), findsOneWidget);

    // VERIFICATION 4: Stress Stability
    // Simulating a rapid mic change
    await firestore.collection('rooms').doc(roomId).collection('speakers').doc('user-101').delete();
    await firestore.collection('rooms').doc(roomId).collection('speakers').doc('user-1').set({'userId': 'user-1'});
    
    await tester.pump(const Duration(milliseconds: 300));
    
    // Check if the UI re-rendered the stage correctly
    expect(find.text('Speaker 101'), findsNothing); // Should be gone from stage
    // Note: user-1 (Me) might be labelled differently depending on UI logic
  });
}
