// Create test data using Node.js admin SDK
const admin = require('firebase-admin');
const serviceAccount = require('./firebase_service_key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function setupTestData() {
  try {
    console.log('Setting up test data...\n');

    // 1. Create non-adult test room
    console.log('1️⃣ Creating test non-adult room...');
    await db.collection('rooms').doc('TEST_ROOM_NON_ADULT').set({
      roomName: 'Test Non-Adult Room',
      isAdult: false,
      description: 'A test room without adult restrictions',
      roomStatus: 'active',
      allowGuestAccess: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created room: TEST_ROOM_NON_ADULT\n');

    // 2. Create adult test room
    console.log('2️⃣ Creating test adult room...');
    await db.collection('rooms').doc('TEST_ROOM_ADULT').set({
      roomName: 'Test Adult Room',
      isAdult: true,
      description: 'A test room that requires adult verification',
      roomStatus: 'active',
      allowGuestAccess: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log('✅ Created room: TEST_ROOM_ADULT\n');

    console.log('🎉 Test data setup complete!');
    console.log('\nNext steps:');
    console.log('1. Navigate to: https://mixvy-v2.web.app/rooms/room/TEST_ROOM_NON_ADULT');
    console.log('2. Try joining the non-adult test room');
    console.log('3. Then try: https://mixvy-v2.web.app/rooms/room/TEST_ROOM_ADULT');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

setupTestData();
