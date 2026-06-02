import 'dart:async';
import 'dart:io';
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
import 'package:mocktail/mocktail.dart';

/// PRODUCTION STAGE STRESS TEST

class MockHttpClient extends Mock implements HttpClient {}
class MockHttpClientRequest extends Mock implements HttpClientRequest {}
class MockHttpClientResponse extends Mock implements HttpClientResponse {}
class MockHttpHeaders extends Mock implements HttpHeaders {}

void main() {
  setUpAll(() {
    // Suppress network image errors by mocking HttpClient
    registerFallbackValue(Uri());
    HttpOverrides.global = _MockHttpOverrides();
  });

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
        photoUrl: 'https://i.pravatar.cc/150if (u != null) u=user-$i');
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
        lastActiveAt: DateTime.now());
      speakers.add(s);
      speakerIds.add(s.userId);
      participants.add(s);
      
      await firestore.collection('rooms').doc(roomId).collection('participants').doc(s.userId).set(s.toMap());
      await firestore.collection('rooms').doc(roomId).collection('speakers').doc(s.userId).set({'userId': s.userId});
    }

    // 4. Launch the App
    final speakerIdsController = StreamController<List<String>>.broadcast();
    addTearDown(speakerIdsController.close);
    speakerIdsController.add(speakerIds);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          roomFirestoreProvider.overrideWithValue(firestore),
          userProvider.overrideWithValue(
            UserModel(
              id: 'user-1', // Testing as one of the audience members
              email: 'user1@mixvy.com',
              username: 'User One',
              createdAt: DateTime.now())),
          // Ensure providers use our fake firestore
          participantsStreamProvider.overrideWith(
            (ref, rid) => firestore.collection('rooms').doc(rid).collection('participants').snapshots().map((snap) => snap.docs.map((d) => RoomParticipantModel.fromMap(d.data())).toList())
          ),
          roomSpeakerUserIdsProvider.overrideWith(
             (ref, rid) => speakerIdsController.stream
          ),
        ],
        child: const MaterialApp(
          home: LiveRoomScreen(roomId: roomId))));

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
    // Use textContaining because RoomUserTile appends "(you)" for the current user.
    expect(find.textContaining('Guest 1'), findsOneWidget);
    expect(find.textContaining('Guest 5'), findsOneWidget);

    // VERIFICATION 4: Stress Stability
    // Simulating a rapid mic change
    await firestore.collection('rooms').doc(roomId).collection('speakers').doc('user-101').delete();
    await firestore.collection('rooms').doc(roomId).collection('participants').doc('user-101').delete(); // Full exit
    await firestore.collection('rooms').doc(roomId).collection('speakers').doc('user-1').set({'userId': 'user-1'});
    
    // Update the speaker stream manually since it's overridden
    final nextSpeakerIds = List<String>.from(speakerIds)..remove('user-101')..add('user-1');
    speakerIdsController.add(nextSpeakerIds);

    await tester.pump(const Duration(milliseconds: 300));
    
    // Check if the UI re-rendered the stage correctly
    expect(find.textContaining('Speaker 101'), findsNothing); // Should be gone entirely
    // Note: user-1 (Me) might be labelled differently depending on UI logic

    await tester.pump(const Duration(seconds: 1)); // Drain timers without waiting for infinite animations
  });
}

class _MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _createMockHttpClient();
  }
}

HttpClient _createMockHttpClient() {
  final client = MockHttpClient();
  final request = MockHttpClientRequest();
  final response = MockHttpClientResponse();
  final headers = MockHttpHeaders();

  when(() => client.getUrl(any())).thenAnswer((_) async => request);
  when(() => request.headers).thenReturn(headers);
  when(() => request.close()).thenAnswer((_) async => response);
  when(() => response.statusCode).thenReturn(200);
  when(() => response.contentLength).thenReturn(_transparentImage.length);
  when(() => response.compressionState).thenReturn(HttpClientResponseCompressionState.notCompressed);
  when(() => response.listen(any(),
      onError: any(named: 'onError'),
      onDone: any(named: 'onDone'),
      cancelOnError: any(named: 'cancelOnError'))).thenAnswer((invocation) {
    final onData = invocation.positionalArguments[0] as void Function(List<int>);
    final onDone = invocation.namedArguments[#onDone] as void Function()?;
    return Stream<List<int>>.fromIterable([_transparentImage]).listen(onData, onDone: onDone);
  });
  return client;
}

final List<int> _transparentImage = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49,
  0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06,
  0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44,
  0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D,
  0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42,
  0x60, 0x82,
];










