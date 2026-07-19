// ignore_for_file: avoid_print

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:mixvy/core/telemetry/app_telemetry.dart';
import 'package:mixvy/features/feed/repository/feed_repository.dart';
import 'package:mixvy/features/room/services/room_session_service.dart';
import 'package:mixvy/services/presence_controller.dart';
import 'package:mixvy/services/room_session_gateway.dart';
import 'package:mixvy/features/speed_dating/services/speed_dating_service.dart';

class _MockPresence extends PresenceController {
  @override
  PresenceControllerState build() => const PresenceControllerState();
  @override
  Future<void> setInRoom(String u, String r) async {}
  @override
  Future<void> clearInRoom(String u) async {}
}

Future<void> main() async {
  print('========== MixVy Firebase Cost Pressure Analysis ==========');

  final firestore = FakeFirebaseFirestore();
  final feedRepo = FeedRepository(firestore);
  final sessionService = RoomSessionService(
    firestore: firestore,
    roomSessionGateway: RoomSessionGateway(firestore),
    presenceController: _MockPresence(),
  );
  final speedDatingService = SpeedDatingService(firestore: firestore);

  AppTelemetry.reset();

  print('Simulation: Start Session...');

  // 1. Feed Fetch
  print('Step 1: Fetching feed...');
  await feedRepo.getPostsFeed();

  // 2. Join Room
  print('Step 2: Joining live room...');
  await firestore.collection('rooms').doc('test-room').set({'isLive': true});
  await sessionService.joinRoom(roomId: 'test-room', userId: 'user-1');

  // 3. Speed Dating Swipe
  print('Step 3: Speed dating decision (Swipe)...');
  await speedDatingService.submitDecision(
    fromUserId: 'user-1',
    toUserId: 'user-2',
    liked: true,
    sessionSeconds: 10,
  );

  print('\n---------- Resource Usage Report ----------');
  print('Total Firestore Reads: ${AppTelemetry.state.firestoreReadCount}');
  print('Total Firestore Writes: ${AppTelemetry.state.firestoreWriteCount}');
  print(
    'Active Listeners Created: ${AppTelemetry.state.firestoreSnapshotCount}',
  );

  const readCostPer1k = 0.0006; // $0.06 per 100k
  const writeCostPer1k = 0.0018; // $0.18 per 100k

  final sessionCost =
      (AppTelemetry.state.firestoreReadCount / 1000 * readCostPer1k) +
      (AppTelemetry.state.firestoreWriteCount / 1000 * writeCostPer1k);

  print(
    '\nEstimated Cost per 1000 Sessions: \$${(sessionCost * 1000).toStringAsFixed(4)}',
  );
  print(
    'Break-even User Engagement (DAU 10k): \$${(sessionCost * 10000).toStringAsFixed(2)} / day',
  );

  if (AppTelemetry.state.firestoreReadCount > 20) {
    print(
      '\n[WARNING] High read volume detected for single session. Check for missing limits!',
    );
  }
}



