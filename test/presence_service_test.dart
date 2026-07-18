import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mixvy/core/providers/firebase_providers.dart';
import 'package:mixvy/models/presence_model.dart';
import 'package:mixvy/services/presence_controller.dart';
import 'package:mixvy/services/presence_repository.dart';
import 'package:mixvy/services/presence_service.dart';
import 'package:mixvy/services/rtdb_presence_service.dart';
import 'package:mixvy/core/streams/stream_lifecycle_manager.dart';

import 'test_helpers.dart';

class _FakeLifecycle extends ChangeNotifier implements StreamLifecycleManager {
  @override
  String buildDedupeKey({
    required String domain,
    String? userId,
    String? route,
    String? queryHash,
  }) {
    return '$domain|$userId';
  }

  @override
  Stream<T> bind<T>({
    required String key,
    required Stream<T> Function() create,
    List<String> routePrefixes = const <String>[],
  }) {
    return create();
  }

  @override
  String get currentRoutePath => '/';

  @override
  bool isRouteActive(List<String> routePrefixes) => true;

  @override
  void updateRoute(String routePath) {}
}

class _MockFirebaseDatabase extends Mock implements FirebaseDatabase {}

class _TestablePresenceController extends PresenceController {
  @override
  PresenceControllerState build() => const PresenceControllerState(
    userId: 'user-1',
    status: UserStatus.online,
    appState: PresenceAppState.foreground,
  );
}

class _FakeRtdbPresenceService extends RtdbPresenceService {
  _FakeRtdbPresenceService() : super(_MockFirebaseDatabase());

  int connectCalls = 0;
  int heartbeatCalls = 0;
  int disconnectCalls = 0;

  @override
  Future<void> connect(String userId) async {
    connectCalls += 1;
  }

  @override
  Future<void> heartbeat(String userId) async {
    heartbeatCalls += 1;
  }

  @override
  Future<void> disconnect(String userId) async {
    disconnectCalls += 1;
  }
}

void main() {
  setUpAll(() async {
    await testSetup();
  });

  group('PresenceModel.fromJson', () {
    test('reads current schema fields', () {
      final model = PresenceModel.fromJson({
        'userId': 'user-1',
        'isOnline': true,
        'status': 'online',
        'inRoom': 'room-a',
        'lastSeen': DateTime.now().toIso8601String(),
      });

      expect(model.userId, 'user-1');
      expect(model.isOnline, isTrue);
      expect(model.status, UserStatus.online);
      expect(model.inRoom, 'room-a');
    });

    test('reads legacy schema fields', () {
      final model = PresenceModel.fromJson({
        'userId': 'user-2',
        'online': true,
        'userStatus': 'away',
        'roomId': 'room-b',
        'lastSeen': DateTime.now().toIso8601String(),
      });

      expect(model.userId, 'user-2');
      expect(model.isOnline, isTrue);
      expect(model.status, UserStatus.away);
      expect(model.inRoom, 'room-b');
    });

    test(
      'treats missing online fields as offline unless status says otherwise',
      () {
        final offline = PresenceModel.fromJson({'userId': 'user-3'});
        final online = PresenceModel.fromJson({
          'userId': 'user-4',
          'status': 'online',
          'lastSeen': DateTime.now().toIso8601String(),
        });

        expect(offline.isOnline, isFalse);
        expect(offline.status, UserStatus.offline);
        expect(online.isOnline, isTrue);
        expect(online.status, UserStatus.online);
      },
    );

    test('treats active session count as online truth', () {
      final model = PresenceModel.fromJson({
        'userId': 'user-5',
        'isOnline': false,
        'status': 'offline',
        'rtdbActiveSessionCount': 2,
        'lastSeen': DateTime.now().toIso8601String(),
      });

      expect(model.isOnline, isTrue);
      expect(model.status, UserStatus.online);
      expect(model.activeSessionCount, 2);
    });
  });

  group('PresenceService', () {
    test(
      'reads presence snapshots through PresenceModel normalization',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = PresenceService(
          firestore: firestore,
          streamLifecycleManager: _FakeLifecycle(),
        );
        await firestore.collection('users').doc('placeholder').set({
          'ok': true,
        });

        final emissions = <PresenceModel>[];
        final sub = service.watchUserPresence('user-1').listen(emissions.add);

        await firestore.collection('users').doc('placeholder-2').set({
          'ok': true,
        });

        expect(emissions, isNotEmpty);

        await sub.cancel();
      },
    );
  });

  group('PresenceRepository arbitration', () {
    test(
      'holds recent online presence through a transient offline flip',
      () async {
        final firestore = FakeFirebaseFirestore();
        final repository = FirestorePresenceRepository(
          firestore,
          streamLifecycleManager: _FakeLifecycle(),
        );
        final emissions = <PresenceModel>[];

        final sub = repository
            .watchUserPresence('user-1')
            .listen(emissions.add);
        await firestore.collection('presence').doc('user-1').set({
          'isOnline': true,
          'status': 'online',
          'lastSeen': Timestamp.fromDate(DateTime.now()),
        });
        await firestore.collection('presence').doc('user-1').set({
          'isOnline': false,
          'status': 'offline',
          'lastSeen': Timestamp.fromDate(DateTime.now()),
        });
        await Future<void>.delayed(Duration.zero);

        expect(emissions, isNotEmpty);
        expect(emissions.last.isOnline, isTrue);

        await sub.cancel();
      },
    );
  });

  group('PresenceController reconnect hardening', () {
    test('resume forces a fresh connect and heartbeat', () async {
      final fakeRtdb = _FakeRtdbPresenceService();
      final container = ProviderContainer(
        overrides: [
          presenceControllerProvider.overrideWith(
            _TestablePresenceController.new,
          ),
          rtdbPresenceServiceProvider.overrideWithValue(fakeRtdb),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(presenceControllerProvider.notifier);
      container.read(presenceControllerProvider);

      notifier.didChangeAppLifecycleState(AppLifecycleState.hidden);
      await Future<void>.delayed(Duration.zero);
      final connectsAfterHidden = fakeRtdb.connectCalls;

      notifier.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await Future<void>.delayed(Duration.zero);

      expect(connectsAfterHidden, greaterThan(0));
      expect(fakeRtdb.connectCalls, greaterThan(connectsAfterHidden));
      expect(fakeRtdb.heartbeatCalls, greaterThan(0));
    });
  });
}
