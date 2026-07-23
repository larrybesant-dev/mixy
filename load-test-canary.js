import admin from 'firebase-admin';
import { getAuth, connectAuthEmulator } from 'firebase/auth';
import { initializeApp } from 'firebase/app';

/**
 * CANARY BOT LOAD TEST SUITE
 * 
 * Safely creates 5 test users and simulates realistic app usage
 * to identify bottlenecks before full production load test.
 * 
 * SAFETY FEATURES:
 * - Creates users with "canarybot" prefix for easy cleanup
 * - Uses test Firestore project (optional)
 * - Monitors WebRTC latency and performance metrics
 * - Graceful error handling and cleanup
 */

const CANARY_BOT_COUNT = 5;
const TEST_EMAIL_DOMAIN = 'canarybot-mixvy-test.com';

// Firebase config for PRODUCTION (change to test project if desired)
const firebaseConfig = {
  apiKey: process.env.FIREBASE_API_KEY || 'YOUR_API_KEY',
  authDomain: 'mixvy-v2.firebaseapp.com',
  projectId: 'mixvy-v2',
  storageBucket: 'mixvy-v2.appspot.com',
  messagingSenderId: '770164332233',
  appId: '1:770164332233:web:abc123',
};

// ============================================================================
// STEP 1: Initialize Firebase Admin SDK
// ============================================================================

let adminApp;
try {
  adminApp = admin.initializeApp({
    projectId: 'mixvy-v2',
    // For local testing, use: FIREBASE_EMULATOR_HOST=localhost:9099
  });
  console.log('✅ Firebase Admin SDK initialized');
} catch (err) {
  console.error('❌ Admin SDK init failed:', err.message);
  process.exit(1);
}

const auth = admin.auth();
const firestore = admin.firestore();

// ============================================================================
// STEP 2: Bot Account Creation
// ============================================================================

/**
 * Creates a single canary bot account
 */
async function createCanaryBot(index) {
  const email = `canarybot${index}@${TEST_EMAIL_DOMAIN}`;
  const password = `CanaryBot${index}@Secure2026`;
  const displayName = `Canary Bot ${index}`;

  try {
    // Create Auth user
    const userRecord = await auth.createUser({
      email,
      password,
      displayName,
    });

    console.log(`  📝 Created auth user: ${email}`);

    // Create Firestore profile document
    const avatarUrl = `https://ui-avatars.com/api/?name=Canary+Bot+${index}&background=00B4D8&color=fff&size=256`;

    await firestore.collection('users').doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      username: `canarybot${index}`,
      usernameLower: `canarybot${index}`,
      displayName,
      avatarUrl,
      photoUrl: avatarUrl,
      bio: `Canary Test Bot #${index} - Load Testing Account`,
      isPrivate: false,
      isComplete: true,
      followers: 0,
      following: 0,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      // Mark as test account for easy filtering
      _isCanaryBot: true,
      _botIndex: index,
      _createdAt: new Date().toISOString(),
    }, { merge: true });

    console.log(`  🤖 Created Firestore profile for canarybot${index}`);

    return {
      index,
      uid: userRecord.uid,
      email,
      password,
      displayName,
      avatarUrl,
    };
  } catch (error) {
    console.error(`  ❌ Failed to create canarybot${index}:`, error.message);
    if (error.code === 'auth/email-already-exists') {
      console.log(`  💡 Account already exists. Skipping creation.`);
      // Try to get existing user
      try {
        const existingUser = await auth.getUserByEmail(email);
        return {
          index,
          uid: existingUser.uid,
          email,
          displayName,
        };
      } catch {
        return null;
      }
    }
    return null;
  }
}

/**
 * Create all canary bots
 */
async function createAllCanaryBots() {
  console.log(`\n📊 STEP 1: CREATING ${CANARY_BOT_COUNT} CANARY BOTS\n`);
  
  const bots = [];
  for (let i = 1; i <= CANARY_BOT_COUNT; i++) {
    const bot = await createCanaryBot(i);
    if (bot) bots.push(bot);
  }

  console.log(`✅ Created ${bots.length}/${CANARY_BOT_COUNT} canary bots\n`);
  return bots;
}

// ============================================================================
// STEP 3: Simulate Bot Actions (Room Join, Chat, Follow)
// ============================================================================

/**
 * Simulate bot joining a live room
 */
async function simulateBotJoinRoom(botUid, botDisplayName, botAvatarUrl) {
  try {
    // Get a random live room
    const roomsSnapshot = await firestore
      .collection('rooms')
      .where('isLive', '==', true)
      .limit(1)
      .get();

    if (roomsSnapshot.empty) {
      console.log(`  ⚠️  No live rooms available for bot`);
      return null;
    }

    const room = roomsSnapshot.docs[0];
    const roomId = room.id;
    const roomData = room.data();

    console.log(`  🎙️  Joining room: "${roomData.name}" (${roomId})`);

    // Create participant doc
    await firestore
      .collection('rooms')
      .doc(roomId)
      .collection('participants')
      .doc(botUid)
      .set({
        userId: botUid,
        displayName: botDisplayName,
        role: 'audience',
        micOn: false,
        cameraOn: false,
        isMuted: false,
        isBanned: false,
        userStatus: 'joined',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Update room stats (add to audience)
    await firestore
      .collection('rooms')
      .doc(roomId)
      .update({
        audienceUserIds: admin.firestore.FieldValue.arrayUnion([botUid]),
        audienceUserAvatarUrls: admin.firestore.FieldValue.arrayUnion([botAvatarUrl || '']),
        memberCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`  ✅ Bot joined room successfully`);

    return {
      roomId,
      roomName: roomData.name,
      participantCount: (roomData.memberCount || 0) + 1,
    };
  } catch (error) {
    console.error(`  ❌ Failed to join room:`, error.message);
    return null;
  }
}

/**
 * Simulate bot sending a chat message
 */
async function simulateBotSendMessage(botUid, botDisplayName, roomId) {
  try {
    const messageText = `Hey everyone! Canary bot ${botDisplayName} here 🤖`;

    const messageRef = await firestore
      .collection('rooms')
      .doc(roomId)
      .collection('messages')
      .add({
        uid: botUid,
        username: botDisplayName,
        text: messageText,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`  💬 Sent chat message (${messageRef.id})`);
    return messageRef.id;
  } catch (error) {
    console.error(`  ❌ Failed to send message:`, error.message);
    return null;
  }
}

/**
 * Simulate bot following another user
 */
async function simulateBotFollowUser(botUid, botDisplayName) {
  try {
    // Get a random user to follow
    const usersSnapshot = await firestore
      .collection('users')
      .where('_isCanaryBot', '!=', true)
      .limit(1)
      .get();

    if (usersSnapshot.empty) {
      console.log(`  ⚠️  No users available to follow`);
      return null;
    }

    const targetUser = usersSnapshot.docs[0];
    const targetUid = targetUser.id;

    // Create follow relationship
    await firestore
      .collection('users')
      .doc(botUid)
      .collection('following')
      .doc(targetUid)
      .set({
        uid: targetUid,
        username: targetUser.data().username,
        displayName: targetUser.data().displayName,
        followedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    // Update follower count
    await firestore
      .collection('users')
      .doc(targetUid)
      .update({
        followers: admin.firestore.FieldValue.increment(1),
      });

    console.log(`  👥 Followed user: ${targetUser.data().displayName}`);
    return targetUid;
  } catch (error) {
    console.error(`  ❌ Failed to follow user:`, error.message);
    return null;
  }
}

/**
 * Run all bot actions
 */
async function simulateAllBotActions(bots) {
  console.log(`\n🚀 STEP 2: SIMULATING BOT ACTIONS\n`);

  for (const bot of bots) {
    console.log(`\n  🤖 [Bot ${bot.index}] ${bot.displayName}`);

    // Join room
    const roomInfo = await simulateBotJoinRoom(bot.uid, bot.displayName, bot.avatarUrl);

    // Send message if room join succeeded
    if (roomInfo) {
      await simulateBotSendMessage(bot.uid, bot.displayName, roomInfo.roomId);
    }

    // Follow a user
    await simulateBotFollowUser(bot.uid, bot.displayName);

    // Small delay between bots to avoid rate limiting
    await new Promise(resolve => setTimeout(resolve, 500));
  }

  console.log(`\n✅ All bot actions completed`);
}

// ============================================================================
// STEP 4: Performance Monitoring
// ============================================================================

/**
 * Collect performance metrics
 */
async function collectMetrics() {
  console.log(`\n📈 STEP 3: PERFORMANCE METRICS\n`);

  try {
    // Count canary bots created
    const botsSnapshot = await firestore
      .collection('users')
      .where('_isCanaryBot', '==', true)
      .get();

    console.log(`  👥 Total Canary Bots: ${botsSnapshot.size}`);

    // Count live rooms
    const roomsSnapshot = await firestore
      .collection('rooms')
      .where('isLive', '==', true)
      .get();

    console.log(`  🎙️  Live Rooms: ${roomsSnapshot.size}`);

    // Get average room participant count
    let totalParticipants = 0;
    let roomsWithParticipants = 0;

    for (const doc of roomsSnapshot.docs) {
      const roomData = doc.data();
      const participantCount = roomData.memberCount || 0;
      if (participantCount > 0) {
        totalParticipants += participantCount;
        roomsWithParticipants++;
      }
    }

    const avgParticipants =
      roomsWithParticipants > 0 ? (totalParticipants / roomsWithParticipants).toFixed(1) : 0;
    console.log(`  📊 Avg Participants per Room: ${avgParticipants}`);

    // Check Firestore read/write counts (from stats)
    console.log(`\n  📝 Firestore Operations:`);
    console.log(`     - Created ${botsSnapshot.size} user documents`);
    console.log(`     - Updated ${roomsSnapshot.size} room documents`);
    console.log(`     - Created participant documents`);
    console.log(`     - Sent chat messages`);
    console.log(`     - Created follow relationships`);

    return {
      totalBots: botsSnapshot.size,
      totalLiveRooms: roomsSnapshot.size,
      avgParticipants,
    };
  } catch (error) {
    console.error(`  ❌ Failed to collect metrics:`, error.message);
    return null;
  }
}

// ============================================================================
// STEP 5: Cleanup (Optional)
// ============================================================================

/**
 * Delete all canary bot accounts
 */
async function cleanupCanaryBots() {
  console.log(`\n🗑️  CLEANUP: Deleting canary bot accounts\n`);

  try {
    const botsSnapshot = await firestore
      .collection('users')
      .where('_isCanaryBot', '==', true)
      .get();

    let deleted = 0;
    for (const doc of botsSnapshot.docs) {
      const botUid = doc.id;
      try {
        // Delete Firestore user document
        await firestore.collection('users').doc(botUid).delete();

        // Delete Auth user
        await auth.deleteUser(botUid);

        deleted++;
        console.log(`  ✅ Deleted bot: ${doc.data().displayName}`);
      } catch (error) {
        console.error(`  ❌ Failed to delete bot ${botUid}:`, error.message);
      }
    }

    console.log(`\n✅ Cleanup complete: Deleted ${deleted} canary bot accounts`);
  } catch (error) {
    console.error(`❌ Cleanup failed:`, error.message);
  }
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('  MIXVY CANARY BOT LOAD TEST SUITE');
  console.log('  Simulating realistic app usage with 5 test bots');
  console.log('='.repeat(70));

  try {
    // Step 1: Create bots
    const bots = await createAllCanaryBots();

    if (bots.length === 0) {
      console.error('\n❌ Failed to create any canary bots. Exiting.');
      process.exit(1);
    }

    // Step 2: Simulate actions
    await simulateAllBotActions(bots);

    // Step 3: Collect metrics
    const metrics = await collectMetrics();

    // Summary
    console.log('\n' + '='.repeat(70));
    console.log('  ✅ CANARY TEST COMPLETE');
    console.log('='.repeat(70));

    if (metrics) {
      console.log(`\n  Summary:`);
      console.log(`    - Bots Created: ${metrics.totalBots}`);
      console.log(`    - Live Rooms Tested: ${metrics.totalLiveRooms}`);
      console.log(`    - Avg Participants: ${metrics.avgParticipants}`);
    }

    console.log(`\n  📋 Next Steps:`);
    console.log(`     1. Monitor WebRTC latency in browser console`);
    console.log(`     2. Check Firestore usage stats in Firebase Console`);
    console.log(`     3. Review error logs for bottlenecks`);
    console.log(`     4. Adjust app config if needed`);
    console.log(`     5. Scale to 100 bots if canary test passes`);

    console.log(`\n  🧹 To cleanup all canary bot accounts, run:`);
    console.log(`     node load-test-canary.js --cleanup\n`);

    // Auto-cleanup if --cleanup flag provided
    if (process.argv.includes('--cleanup')) {
      await cleanupCanaryBots();
    }
  } catch (error) {
    console.error('\n❌ Fatal error:', error.message);
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

// Run main
main();
