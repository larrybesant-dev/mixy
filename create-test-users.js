import admin from 'firebase-admin';

// Initialize Firebase Admin SDK with service account key
// (Assumes GOOGLE_APPLICATION_CREDENTIALS env var is set or uses default credentials)
try {
  admin.initializeApp({
    projectId: 'mixvy-v2',
  });
} catch (err) {
  // Firebase already initialized
  console.log('Firebase already initialized');
}

const auth = admin.auth();
const firestore = admin.firestore();

async function createTestUsers() {
  const testUsers = [];
  const errors = [];

  for (let i = 1; i <= 10; i++) {
    const email = `testuser${i}@mixvy-test.com`;
    const password = `TestPassword${i}@`;
    const displayName = `Test User ${i}`;

    try {
      // Create Firebase Auth user
      const userRecord = await auth.createUser({
        email,
        password,
        displayName,
      });

      console.log(`✅ Created user ${i}: ${email} (UID: ${userRecord.uid})`);

      // Create Firestore user profile
      await firestore.collection('users').doc(userRecord.uid).set({
        uid: userRecord.uid,
        username: `testuser${i}`,
        usernameLower: `testuser${i}`,
        displayName,
        email,
        photoUrl: `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=random`,
        avatarUrl: `https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=random`,
        bio: `Test account #${i}`,
        isPrivate: false,
        isComplete: true,
        followers: 0,
        following: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      testUsers.push({
        index: i,
        email,
        password,
        uid: userRecord.uid,
        displayName,
      });
    } catch (error) {
      errors.push({
        index: i,
        email,
        error: error.message,
      });
      console.error(`❌ Error creating user ${i}: ${error.message}`);
    }
  }

  console.log('\n=== SUMMARY ===');
  console.log(`Successfully created: ${testUsers.length}/10 users`);
  if (errors.length > 0) {
    console.log(`Errors: ${errors.length}`);
    errors.forEach(e => console.log(`  - User ${e.index} (${e.email}): ${e.error}`));
  }

  console.log('\n=== TEST USER CREDENTIALS ===');
  testUsers.forEach(user => {
    console.log(`\nUser ${user.index}:`);
    console.log(`  Email: ${user.email}`);
    console.log(`  Password: ${user.password}`);
    console.log(`  UID: ${user.uid}`);
  });

  process.exit(errors.length > 0 ? 1 : 0);
}

createTestUsers().catch(err => {
  console.error('Fatal error:', err);
  process.exit(1);
});
