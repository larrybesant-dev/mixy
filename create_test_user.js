import admin from 'firebase-admin';

// Initialize Firebase Admin SDK
const cred = admin.credential.applicationDefault();
admin.initializeApp({
  credential: cred,
  projectId: 'mixvy-v2'
});

const auth = admin.auth();

async function createTestUser() {
  try {
    // First try to get existing user
    try {
      const existingUser = await auth.getUserByEmail('test@mixvy.app');
      console.log('User already exists:');
      console.log('UID:', existingUser.uid);
      console.log('Email:', existingUser.email);
      
      // Create custom token
      const token = await auth.createCustomToken(existingUser.uid);
      console.log('Custom Token:', token);
    } catch (e) {
      if (e.code === 'auth/user-not-found') {
        // Create new user
        const user = await auth.createUser({
          email: 'test@mixvy.app',
          password: 'TestMixvy@2026!',
          displayName: 'Test User',
          emailVerified: true
        });
        console.log('User created successfully:');
        console.log('UID:', user.uid);
        console.log('Email:', user.email);
        
        // Create custom token
        const token = await auth.createCustomToken(user.uid);
        console.log('Custom Token:', token);
      } else {
        throw e;
      }
    }
    
    process.exit(0);
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}

createTestUser();
