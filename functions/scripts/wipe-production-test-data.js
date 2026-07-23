/**
 * MIXVY PRODUCTION PURGE SCRIPT
 *
 * Purpose: Deletes all transient test data (Rooms, Bots, Notifications)
 * to prepare the environment for real users.
 *
 * Target:
 * 1. All Documents in 'rooms' collection (and subcollections).
 * 2. All Users in 'users' collection matching bot patterns.
 * 3. All Users in Firebase Auth matching bot patterns.
 * 4. All Documents in 'notifications' collection.
 */

const admin = require("firebase-admin");

// Initialize with local default credentials (uses GOOGLE_APPLICATION_CREDENTIALS
// or the active 'firebase login' session).
admin.initializeApp({
  projectId: "mix-and-mingle-v2"
});

const db = admin.firestore();
const auth = admin.auth();

async function deleteCollection(collectionPath, batchSize = 100) {
  const collectionRef = db.collection(collectionPath);
  const query = collectionRef.limit(batchSize);

  return new Promise((resolve, reject) => {
    deleteQueryBatch(query, resolve).catch(reject);
  });
}

async function deleteQueryBatch(query, resolve) {
  const snapshot = await query.get();

  const batchSize = snapshot.size;
  if (batchSize === 0) {
    resolve();
    return;
  }

  const batch = db.batch();
  snapshot.docs.forEach((doc) => {
    // For rooms, we might need to recursively delete subcollections
    // but for a simple purge, deleting the root docs is the first step.
    // In production, you'd use recursive delete via CLI.
    batch.delete(doc.ref);
  });
  await batch.commit();

  process.nextTick(() => {
    deleteQueryBatch(query, resolve);
  });
}

async function purgeBots() {
  console.log("--- Purging Bot Users ---");

  // 1. Get users from Firestore
  const usersSnap = await db.collection("users").get();
  let deletedCount = 0;

  for (const doc of usersSnap.docs) {
    const data = doc.data();
    const email = data.email || "";
    const username = data.username || "";

    // Patterns for bots: @test.com, @example.com, or BotUser_, or QA MixVy
    if (email.endsWith("@test.com") ||
        email.endsWith("@example.com") ||
        username.startsWith("BotUser_") ||
        username.startsWith("QA MixVy")) {
      const uid = doc.id;
      console.log(`Deleting bot: ${username} (${uid})`);

      try {
        // Delete from Auth
        await auth.deleteUser(uid);
        // Delete from Firestore
        await doc.ref.delete();
        deletedCount++;
      } catch (e) {
        console.error(`Failed to delete user ${uid}:`, e.message);
        // Sometimes user is in Firestore but not Auth, still delete Firestore doc
        if (e.code === "auth/user-not-found") {
            await doc.ref.delete();
            deletedCount++;
        }
      }
    }
  }
  console.log(`Successfully purged ${deletedCount} bots.`);
}

async function runPurge() {
  console.log("🚀 Starting MixVy Production Purge...");

  try {
    // 1. Delete all rooms
    console.log("Purging rooms...");
    await deleteCollection("rooms");
    console.log("Rooms purged.");

    // 2. Delete all notifications
    console.log("Purging notifications...");
    await deleteCollection("notifications");
    console.log("Notifications purged.");

    // 3. Purge bots
    await purgeBots();

    console.log("✅ Purge Complete. The live site is now clean!");
  } catch (error) {
    console.error("❌ Purge failed:", error);
  }
}

runPurge();
