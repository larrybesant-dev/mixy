import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logging/logging.dart';

final _logger = Logger('TestDataSetup');

void main() async {
  // Configure logging
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    // Output log messages (note: print is used here for CLI output only)
    // ignore: avoid_print
    print('${record.level.name}: ${record.loggerName}: ${record.message}');
  });

  // Initialize Firebase
  await Firebase.initializeApp();

  final firestore = FirebaseFirestore.instance;

  _logger.info('Setting up test data...\n');

  try {
    // Test 1: Create a non-adult room
    _logger.info('1️⃣ Creating test non-adult room...');
    final testRoomRef = firestore.collection('rooms').doc('TEST_ROOM_NON_ADULT');
    await testRoomRef.set({
      'roomName': 'Test Non-Adult Room',
      'isAdult': false,
      'description': 'A test room without adult restrictions',
      'roomStatus': 'active',
      'allowGuestAccess': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _logger.info('✅ Created room: TEST_ROOM_NON_ADULT\n');

    // Test 2: Create an adult room (for testing adult verification)
    _logger.info('2️⃣ Creating test adult room...');
    final adultRoomRef = firestore.collection('rooms').doc('TEST_ROOM_ADULT');
    await adultRoomRef.set({
      'roomName': 'Test Adult Room',
      'isAdult': true,
      'description': 'A test room that requires adult verification',
      'roomStatus': 'active',
      'allowGuestAccess': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    _logger.info('✅ Created room: TEST_ROOM_ADULT\n');

    // Test 3: Create a verified adult user (simulate current test user)
    // Note: We'll use a placeholder UID; in real testing, get the actual logged-in user
    _logger.info('3️⃣ Creating verified adult user verification record...');
    const testUserId = 'TEST_USER_VERIFIED';
    final verificationRef = firestore.collection('verification').doc(testUserId);
    await verificationRef.set({
      'isAdultVerified': true,
      'verificationStatus': 'verified',
      'verificationDate': FieldValue.serverTimestamp(),
      'userId': testUserId,
    });
    _logger.info('✅ Created verification record: $testUserId\n');

    _logger.info('🎉 Test data setup complete!');
    _logger.info('\nNext steps:');
    _logger.info('1. Navigate to: https://mixvy-v2.web.app/rooms/room/TEST_ROOM_NON_ADULT');
    _logger.info('2. Try joining the non-adult test room');
    _logger.info('3. Then try: https://mixvy-v2.web.app/rooms/room/TEST_ROOM_ADULT');
    _logger.info('   (if your auth user ID matches TEST_USER_VERIFIED)');
  } catch (e) {
    _logger.severe('❌ Error setting up test data: $e');
  }
}
