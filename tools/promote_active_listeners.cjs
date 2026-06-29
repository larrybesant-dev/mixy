#!/usr/bin/env node
/**
 * Promote Active Listeners as Beta Testers
 * 
 * Queries Firestore for users currently online in webrtc_sessions,
 * then promotes only those users as beta testers for real-time feedback.
 */

const admin = require("firebase-admin");

// Uses GOOGLE_APPLICATION_CREDENTIALS env var or GCP environment
admin.initializeApp();

const db = admin.firestore();

async function getActiveListenerUIDs() {
  console.log("📊 Querying active listeners from webrtc_sessions...");
  
  const activeUIDs = new Set();
  
  // Query all webrtc_sessions for active peer connections
  const sessionsSnap = await db.collection("webrtc_sessions").get();
  
  if (sessionsSnap.empty) {
    console.log("⚠️  No active webrtc_sessions found.");
    return Array.from(activeUIDs);
  }

  console.log(`Found ${sessionsSnap.size} active session(s)`);

  for (const sessionDoc of sessionsSnap.docs) {
    // Check for participants subcollection or look at root document
    const sessionData = sessionDoc.data();
    
    // Try to get participants from subcollection
    const participantsSnap = await sessionDoc.ref.collection("participants").get();
    if (!participantsSnap.empty) {
      console.log(`\n📍 Session ${sessionDoc.id}: ${participantsSnap.size} participant(s)`);
      participantsSnap.docs.forEach((doc) => {
        // The document ID IS the Firebase Auth UID
        const firebaseUid = doc.id;
        if (firebaseUid && firebaseUid !== "system" && typeof firebaseUid === 'string' && firebaseUid.length > 0) {
          activeUIDs.add(firebaseUid);
          console.log(`   ✓ Firebase UID: ${firebaseUid}`);
        }
      });
    }
  }

  console.log(`\n✅ Extracted ${activeUIDs.size} unique active listener(s)`);
  return Array.from(activeUIDs);
}

async function promoteActiveListeners(uids) {
  if (uids.length === 0) {
    console.log("❌ No active listeners to promote.");
    return 0;
  }

  console.log(`\n🚀 Promoting ${uids.length} active listener(s) as beta testers...`);
  
  let promoted = 0;
  
  // Promote in batches of 10 to avoid rate limits
  const batchSize = 10;
  for (let i = 0; i < uids.length; i += batchSize) {
    const batch = uids.slice(i, i + batchSize);
    
    try {
      for (const uid of batch) {
        await db.collection("users").doc(uid).set(
          { betaTester: true, promotedAt: new Date().toISOString() },
          { merge: true }
        );
        promoted++;
        console.log(`  ✅ ${uid}`);
      }
    } catch (error) {
      console.error(`❌ Error promoting batch: ${error.message}`);
    }
  }

  console.log(`\n✨ Successfully promoted ${promoted} beta tester(s)!`);
  return promoted;
}

async function main() {
  try {
    console.log("🎯 MIXVY Beta Tester Promotion (Real-Time Active Listeners)\n");
    
    const activeUIDs = await getActiveListenerUIDs();
    const promoted = await promoteActiveListeners(activeUIDs);
    
    console.log(`\n📝 Summary:`);
    console.log(`   Active Listeners Found: ${activeUIDs.length}`);
    console.log(`   Promoted to Beta: ${promoted}`);
    console.log(`   Timestamp: ${new Date().toISOString()}`);
    
    if (promoted > 0) {
      console.log(`\n💬 Next Step: Send outreach message to these ${promoted} beta tester(s)`);
      console.log(`   Message Template: "Thanks for using MIXVY! We just released Network Health indicators 🟢🟡🔴 to help you monitor connection quality. Please report your experience in Settings > Beta Feedback!"`);
    }
    
  } catch (error) {
    console.error("❌ Fatal error:", error);
    process.exit(1);
  }

  process.exit(0);
}

main();
