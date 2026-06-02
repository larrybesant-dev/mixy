import 'package:flutter/widgets.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
// ignore: depend_on_referenced_packages — required for Firebase test setup
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUserCredential extends Mock implements UserCredential {}

class MockUser extends Mock implements User {}

class MockFirebaseFirestore extends Mock implements FirebaseFirestore {}
// Removed sealed class mocks for DocumentReference, DocumentSnapshot, and CollectionReference.

/// Custom Firebase Core mock that includes plugin constants required by
/// FirebaseCrashlytics (isCrashlyticsCollectionEnabled) so the Logger does
/// not assert in widget/unit tests.
class _MixvyFirebaseMock implements TestFirebaseCoreHostApi {
  // pluginConstants is keyed by plugin channel name; Crashlytics reads
  // its values from the sub-map at 'plugins.flutter.io/firebase_crashlytics'.
  static const Map<String, Object> _pluginConstants = <String, Object>{
    'plugins.flutter.io/firebase_crashlytics': <String, Object>{
      'isCrashlyticsCollectionEnabled': true,
    },
  };

  static CoreInitializeResponse _makeApp(String name) => CoreInitializeResponse(
    name: name,
    options: CoreFirebaseOptions(
      apiKey: 'test-api-key',
      appId: '1:12345:android:test',
      messagingSenderId: '12345',
      projectId: 'test-project',
    ),
    pluginConstants: _pluginConstants,
  );

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => _makeApp(appName);

  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [
    _makeApp(defaultFirebaseAppName),
  ];

  @override
  Future<CoreFirebaseOptions> optionsFromResource() async =>
      CoreFirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:12345:android:test',
        messagingSenderId: '12345',
        projectId: 'test-project',
      );
}

// Expose mocks for use in test files
final mockUser = MockUser();
final mockUserCredential = MockUserCredential();
final mockAuth = MockFirebaseAuth();
final mockFirestore = MockFirebaseFirestore();
final StreamController<User?> authStateController =
    StreamController<User?>.broadcast();

void emitAuthState(User? user) {
  authStateController.add(user);
}

final Map<String, Object?> _sharedPrefsStore = <String, Object?>{};

Future<void> testSetup() async {
  // Removed unused local variable 'currentUser'
  // Removed unsupported StreamController and authStateController logic for test mocks
  TestWidgetsFlutterBinding.ensureInitialized();
  // Register Pigeon-based Firebase Core mock (firebase_core >= 4.x) with
  // plugin constants required by FirebaseCrashlytics.
  TestFirebaseCoreHostApi.setUp(_MixvyFirebaseMock());
  registerFallbackValue(MockFirebaseApp());
  registerFallbackValue(MockFirebaseAuth());
  registerFallbackValue(MockUserCredential());
  registerFallbackValue(MockUser());
  registerFallbackValue(MockFirebaseFirestore());

  // Mock FirebaseAuth methods (use top-level mocks)
  when(() => mockUser.uid).thenReturn('mock-uid');
  when(() => mockUser.email).thenReturn('user@example.com');
  when(() => mockUser.displayName).thenReturn('username');
  when(() => mockUser.photoURL).thenReturn('');
  when(() => mockUser.isAnonymous).thenReturn(false);
  when(() => mockUser.getIdToken(any())).thenAnswer((_) async => 'mock-token');
  when(() => mockUserCredential.user).thenReturn(mockUser);
  when(
    () => mockAuth.authStateChanges(),
  ).thenAnswer((_) => authStateController.stream);
  when(() => mockAuth.currentUser).thenReturn(mockUser);
  emitAuthState(mockUser);

  // Mock Firestore methods
  // Setup collection/doc chain
  // Mock Firestore methods
  // Setup collection/doc chain
  // Removed unsupported Firestore/document mocks: MockCollection, MockDocumentReference, MockDocumentSnapshot
  // Patch FirebaseAuth and Firestore platform channels only (no .instance assignment)
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_auth'),
        (MethodCall methodCall) async {
          return null;
        },
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/cloud_firestore'),
        (MethodCall methodCall) async {
          return null;
        },
      );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/shared_preferences'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'getAll':
              return Map<String, Object?>.from(_sharedPrefsStore);
            case 'setBool':
            case 'setInt':
            case 'setDouble':
            case 'setString':
            case 'setStringList':
              final arguments = Map<Object?, Object?>.from(
                methodCall.arguments as Map,
              );
              final key = arguments['key'] as String;
              final value = arguments['value'];
              _sharedPrefsStore[key] = value;
              return true;
            case 'remove':
              final key = methodCall.arguments as String;
              _sharedPrefsStore.remove(key);
              return true;
            case 'clear':
              _sharedPrefsStore.clear();
              return true;
            default:
              return null;
          }
        },
      );
  const MethodChannel firebaseCoreChannel = MethodChannel(
    'plugins.flutter.io/firebase_core',
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(firebaseCoreChannel, (
        MethodCall methodCall,
      ) async {
        if (methodCall.method == 'Firebase#initializeCore') {
          return {
            'app': {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'fake',
                'appId': 'fake',
                'messagingSenderId': 'fake',
                'projectId': 'fake',
              },
            },
            'pluginConstants': {},
          };
        } else if (methodCall.method == 'Firebase#initializeApp') {
          return {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': 'fake',
              'appId': 'fake',
              'messagingSenderId': 'fake',
              'projectId': 'fake',
            },
            'pluginConstants': {},
          };
        } else if (methodCall.method == 'FirebaseApp#appNamed') {
          return {
            'name': '[DEFAULT]',
            'options': {
              'apiKey': 'fake',
              'appId': 'fake',
              'messagingSenderId': 'fake',
              'projectId': 'fake',
            },
            'pluginConstants': {},
          };
        } else if (methodCall.method == 'FirebaseApp#allApps') {
          return [
            {
              'name': '[DEFAULT]',
              'options': {
                'apiKey': 'fake',
                'appId': 'fake',
                'messagingSenderId': 'fake',
                'projectId': 'fake',
              },
              'pluginConstants': {},
            },
          ];
        }
        return null;
      });
  // Mock Firebase Analytics channel so unawaited logEvent() calls in
  // AppTelemetry resolve synchronously in tests and don't fire callbacks
  // after the test has completed (preventing "failed after completed" errors).
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/firebase_analytics'),
        (MethodCall methodCall) async => null,
      );
  // Mock Pigeon-based FirebaseAuth channels (firebase_auth >= 5.x) so that
  // calls to FirebaseAuth.currentUser from within unit tests (e.g. messaging
  // actor validation) don't throw channel-error and fire post-test callbacks.
  for (final channelName in const <String>[
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerIdTokenListener',
    'dev.flutter.pigeon.firebase_auth_platform_interface.FirebaseAuthHostApi.registerAuthStateListener',
  ]) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(channelName, (ByteData? message) async {
          // Return an empty/null encoded response so the channel resolves
          // synchronously rather than erroring out.
          return null;
        });
  }
}

/// Utility to wrap widget tests in ProviderScope
Widget withProviderScope(Widget child) => ProviderScope(child: child);

/// Utility to skip integration/patrol tests unless explicitly opted in.
/// Run with --dart-define=RUN_INTEGRATION_TESTS=true to include them.
const bool skipIntegrationTests = !bool.fromEnvironment(
  'RUN_INTEGRATION_TESTS',
  defaultValue: false,
);



