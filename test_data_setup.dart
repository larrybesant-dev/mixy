import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('Setting up test data...\n');

  try {
    // Test 1: Create a non-adult room
    print('1️⃣ Creating test non-adult room...');
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
    print('✅ Created room: TEST_ROOM_NON_ADULT\n');

    // Test 2: Create an adult room (for testing adult verification)
    print('2️⃣ Creating test adult room...');
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
    print('✅ Created room: TEST_ROOM_ADULT\n');

    // Test 3: Create a verified adult user (simulate current test user)
    // Note: We'll use a placeholder UID; in real testing, get the actual logged-in user
    print('3️⃣ Creating verified adult user verification record...');
    const testUserId = 'TEST_USER_VERIFIED';
    final verificationRef = firestore.collection('verification').doc(testUserId);
    await verificationRef.set({
      'isAdultVerified': true,
      'verificationStatus': 'verified',
      'verificationDate': FieldValue.serverTimestamp(),
      'userId': testUserId,
    });
    print('✅ Created verification record: $testUserId\n');

    print('🎉 Test data setup complete!');
    print('\nNext steps:');
    print('1. Navigate to: https://mixvy-v2.web.app/rooms/room/TEST_ROOM_NON_ADULT');
    print('2. Try joining the non-adult test room');
    print('3. Then try: https://mixvy-v2.web.app/rooms/room/TEST_ROOM_ADULT');
    print('   (if your auth user ID matches TEST_USER_VERIFIED)');
  } catch (e) {
    print('❌ Error setting up test data: $e');
  }

  exit(0);
}
