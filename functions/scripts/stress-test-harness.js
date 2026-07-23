/* eslint-disable no-console */
/**
 * stress-test-harness.js
 *
 * Simulates adversarial user behavior against Firestore and validates system
 * state after each attack phase.
 *
 * Attack phases (in order):
 *   1. Follow spam   — rapid follow/unfollow cycles for N users
 *   2. Message storm — burst N messages per conversation simultaneously
 *   3. Room churn    — rapid join/leave participant writes
 *   4. State check   — runs validate-firestore-truth logic inline after attacks
 *
 * This script writes real data to Firestore. Use against staging/dev project only.
 * Set FIREBASE_PROJECT env var or run with Firebase emulator.
 *
 * Usage:
 *   node scripts/stress-test-harness.js --users 5 --messages 20 --rounds 3
 *   GCLOUD_PROJECT=mixvy-staging node scripts/stress-test-harness.js
 *
 * Flags:
 *   --users    N   number of synthetic user pairs to stress (default: 3)
 *   --messages N   messages to burst per conversation (default: 10)
 *   --rounds   N   number of full attack cycles (default: 2)
 *   --dry-run      simulate without writing to Firestore
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ── CLI ───────────────────────────────────────────────────────────────────────
function argInt(flag, fallback) {
  const idx = process.argv.indexOf(flag);
  if (idx === -1) return fallback;
  return parseInt(process.argv[idx + 1], 10) || fallback;
}
const NUM_USERS = argInt("--users", 3);
const NUM_MESSAGES = argInt("--messages", 10);
const NUM_ROUNDS = argInt("--rounds", 2);
const DRY_RUN = process.argv.includes("--dry-run");

// ── Synthetic IDs ─────────────────────────────────────────────────────────────
function syntheticUid(n) {
  return `stress_user_${n.toString().padStart(4, "0")}`;
}
function syntheticRoomId(n) {
  return `stress_room_${n.toString().padStart(4, "0")}`;
}
function syntheticConvId(a, b) {
  const sorted = [a, b].sort();
  return `stress_conv_${sorted[0]}_${sorted[1]}`;
}

// ── Results ───────────────────────────────────────────────────────────────────
const results = {
  phases: [],
  violations: [],
  totalWrites: 0,
  totalReads: 0,
  errors: [],
};

function logPhase(name, stats) {
  console.log(`  ↳ ${name}: ${JSON.stringify(stats)}`);
  results.phases.push({name, ...stats});
}

function logViolation(phase, path, rule, detail) {
  console.warn(`  ⚠ [${phase}] violation path=${path} rule=${rule} ${detail || ""}`);
  results.violations.push({phase, path, rule, detail: detail || null});
}

async function write(ref, data) {
  if (DRY_RUN) return;
  await ref.set(data, {merge: true});
  results.totalWrites++;
}

async function del(ref) {
  if (DRY_RUN) return;
  await ref.delete();
}

// ── Phase 1: Follow spam ──────────────────────────────────────────────────────
async function attackFollowSpam(round) {
  console.log(`\n[Phase 1] Follow spam — round=${round} users=${NUM_USERS}`);
  const CYCLES = 5; // follow/unfollow cycles per pair
  let writes = 0;
  let errors = 0;

  for (let a = 0; a < NUM_USERS; a++) {
    for (let b = 0; b < NUM_USERS; b++) {
      if (a === b) continue;
      const follower = syntheticUid(a);
      const followed = syntheticUid(b);
      const docId = `${follower}_${followed}`;
      const docRef = db.collection("follows").doc(docId);

      for (let c = 0; c < CYCLES; c++) {
        // Follow
        try {
          await write(docRef, {
            followerUserId: follower,
            followedUserId: followed,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          writes++;
          // Immediately unfollow (simulates rapid toggle)
          await del(docRef);
          writes++;
        } catch (err) {
          errors++;
          results.errors.push(`follow_spam round=${round} pair=${docId}: ${err.message}`);
        }
      }

      // Leave it followed at end of attack so symmetry check can verify
      try {
        await write(docRef, {
          followerUserId: follower,
          followedUserId: followed,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        writes++;
      } catch (err) {
        errors++;
      }
    }
  }

  logPhase("follow_spam", {round, writes, errors});
}

// ── Phase 2: Message storm ────────────────────────────────────────────────────
async function attackMessageStorm(round) {
  console.log(`\n[Phase 2] Message storm — round=${round} messages=${NUM_MESSAGES}`);
  let writes = 0;
  let errors = 0;

  for (let a = 0; a < NUM_USERS; a++) {
    for (let b = a + 1; b < NUM_USERS; b++) {
      const userA = syntheticUid(a);
      const userB = syntheticUid(b);
      const convId = syntheticConvId(userA, userB);

      // Ensure conversation doc exists with correct schema
      const convRef = db.collection("conversations").doc(convId);
      try {
        await write(convRef, {
          participantIds: [userA, userB],
          status: "active",
          type: "direct",
          lastMessagePreview: "",
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        writes++;
      } catch (err) {
        errors++;
        results.errors.push(`conv_init ${convId}: ${err.message}`);
        continue;
      }

      // Burst all messages in parallel — this tests race conditions on lastMessageAt
      const messageWrites = [];
      for (let m = 0; m < NUM_MESSAGES; m++) {
        const msgRef = convRef.collection("messages").doc();
        messageWrites.push(
          write(msgRef, {
            senderId: m % 2 === 0 ? userA : userB,
            senderName: `StressUser${m % 2 === 0 ? a : b}`,
            conversationId: convId,
            content: `Stress message ${m} round ${round}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            sentAt: admin.firestore.FieldValue.serverTimestamp(),
            type: "normal",
            isDeleted: false,
            readBy: [],
          }).then(() => { writes++; }).catch((err) => {
            errors++;
            results.errors.push(`msg ${convId}/messages: ${err.message}`);
          }),
        );
      }
      await Promise.all(messageWrites);

      // Simulate the last-message update race: all N messages fight to update lastMessageAt
      const updateRace = Array.from({length: NUM_MESSAGES}, (_, m) =>
        DRY_RUN ? Promise.resolve() : convRef.update({
          lastMessagePreview: `Stress message ${m} round ${round}`,
          lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        }).then(() => { writes++; }).catch(() => { errors++; }),
      );
      await Promise.all(updateRace);
    }
  }

  logPhase("message_storm", {round, writes, errors});
}

// ── Phase 3: Room churn ───────────────────────────────────────────────────────
async function attackRoomChurn(round) {
  console.log(`\n[Phase 3] Room churn — round=${round} users=${NUM_USERS}`);
  let writes = 0;
  let errors = 0;

  for (let r = 0; r < Math.min(NUM_USERS, 3); r++) {
    const roomId = syntheticRoomId(r);
    const hostUid = syntheticUid(r);
    const roomRef = db.collection("rooms").doc(roomId);

    // Ensure room doc exists with correct schema
    try {
      await write(roomRef, {
        name: `StressRoom${r}`,
        hostId: hostUid,
        ownerId: hostUid,
        isLive: true,
        isAdult: false,
        stageUserIds: [],
        audienceUserIds: [hostUid],
        memberCount: 1,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      writes++;
    } catch (err) {
      errors++;
      results.errors.push(`room_init ${roomId}: ${err.message}`);
      continue;
    }

    // Rapid join/leave for all stress users in parallel
    const churnOps = [];
    for (let u = 0; u < NUM_USERS; u++) {
      const uid = syntheticUid(u);
      const pRef = roomRef.collection("participants").doc(uid);
      const CHURN_CYCLES = 3;

      churnOps.push((async () => {
        for (let c = 0; c < CHURN_CYCLES; c++) {
          try {
            await write(pRef, {
              userId: uid,
              role: "audience",
              joinedAt: admin.firestore.FieldValue.serverTimestamp(),
              lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
              isMuted: false,
              isBanned: false,
              camOn: false,
              micOn: false,
            });
            writes++;
            await del(pRef);
            writes++;
          } catch (err) {
            errors++;
          }
        }
        // Leave participant in place for validation
        try {
          await write(pRef, {
            userId: uid,
            role: uid === hostUid ? "host" : "audience",
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
            lastActiveAt: admin.firestore.FieldValue.serverTimestamp(),
            isMuted: false,
            isBanned: false,
            camOn: false,
            micOn: false,
          });
          writes++;
        } catch (err) {
          errors++;
        }
      })());
    }
    await Promise.all(churnOps);
  }

  logPhase("room_churn", {round, writes, errors});
}

// ── Phase 4: Post-attack validation ──────────────────────────────────────────
async function validateAfterAttack() {
  console.log("\n[Phase 4] Post-attack state validation");
  let reads = 0;
  let violations = 0;

  // Check that all stress conversations still have participantIds
  for (let a = 0; a < NUM_USERS; a++) {
    for (let b = a + 1; b < NUM_USERS; b++) {
      const convId = syntheticConvId(syntheticUid(a), syntheticUid(b));
      try {
        const snap = await db.collection("conversations").doc(convId).get();
        reads++;
        if (!snap.exists) continue;
        const d = snap.data() || {};
        if (!Array.isArray(d.participantIds) || d.participantIds.length === 0) {
          logViolation("post-storm", `conversations/${convId}`, "missing_participantIds");
          violations++;
        }
        if (!d.lastMessageAt) {
          logViolation("post-storm", `conversations/${convId}`, "missing_lastMessageAt",
            "message burst did not update lastMessageAt");
          violations++;
        }
      } catch (err) {
        results.errors.push(`validate conv ${convId}: ${err.message}`);
      }
    }
  }

  // Check follow symmetry for all stress pairs
  for (let a = 0; a < NUM_USERS; a++) {
    for (let b = 0; b < NUM_USERS; b++) {
      if (a === b) continue;
      const follower = syntheticUid(a);
      const followed = syntheticUid(b);
      const docId = `${follower}_${followed}`;

      try {
        const followsSnap = await db.collection("follows").doc(docId).get();
        reads++;
        if (!followsSnap.exists) continue; // was unfollowed — skip

        const followerEntry = await db
          .collection("users").doc(followed)
          .collection("followers").doc(follower).get();
        reads++;
        if (!followerEntry.exists) {
          logViolation("post-spam", `users/${followed}/followers/${follower}`,
            "missing_after_follow_spam");
          violations++;
        }
      } catch (err) {
        results.errors.push(`validate follow ${docId}: ${err.message}`);
      }
    }
  }

  // Check room participant schema after churn
  for (let r = 0; r < Math.min(NUM_USERS, 3); r++) {
    const roomId = syntheticRoomId(r);
    try {
      const pSnap = await db.collection("rooms").doc(roomId)
        .collection("participants").get();
      reads++;
      for (const pDoc of pSnap.docs) {
        const pd = pDoc.data() || {};
        if (!pd.userId || typeof pd.userId !== "string") {
          logViolation("post-churn", pDoc.ref.path, "missing_userId");
          violations++;
        }
        if (!pd.joinedAt) {
          logViolation("post-churn", pDoc.ref.path, "missing_joinedAt");
          violations++;
        }
      }
    } catch (err) {
      results.errors.push(`validate room ${roomId}: ${err.message}`);
    }
  }

  results.totalReads += reads;
  logPhase("post_attack_validation", {reads, violations});
  return violations;
}

// ── Cleanup ───────────────────────────────────────────────────────────────────
async function cleanupStressData() {
  console.log("\n[Cleanup] Removing stress test data…");
  if (DRY_RUN) {
    console.log("  DRY-RUN: skipping cleanup");
    return;
  }

  const deletions = [];

  // follows
  for (let a = 0; a < NUM_USERS; a++) {
    for (let b = 0; b < NUM_USERS; b++) {
      if (a === b) continue;
      deletions.push(
        db.collection("follows").doc(`${syntheticUid(a)}_${syntheticUid(b)}`).delete().catch(() => {}),
      );
    }
  }

  // conversations + messages
  for (let a = 0; a < NUM_USERS; a++) {
    for (let b = a + 1; b < NUM_USERS; b++) {
      const convRef = db.collection("conversations")
        .doc(syntheticConvId(syntheticUid(a), syntheticUid(b)));
      const msgs = await convRef.collection("messages").listDocuments();
      deletions.push(...msgs.map((r) => r.delete().catch(() => {})));
      deletions.push(convRef.delete().catch(() => {}));
    }
  }

  // rooms + participants
  for (let r = 0; r < Math.min(NUM_USERS, 3); r++) {
    const roomRef = db.collection("rooms").doc(syntheticRoomId(r));
    const participants = await roomRef.collection("participants").listDocuments();
    deletions.push(...participants.map((p) => p.delete().catch(() => {})));
    deletions.push(roomRef.delete().catch(() => {}));
  }

  await Promise.all(deletions);
  console.log(`  removed ${deletions.length} stress documents`);
}

// ── MAIN ─────────────────────────────────────────────────────────────────────
async function run() {
  const startedAt = new Date();
  console.log(
    `[stress-test-harness] started=${startedAt.toISOString()}` +
    ` users=${NUM_USERS} messages=${NUM_MESSAGES} rounds=${NUM_ROUNDS}` +
    ` dryRun=${DRY_RUN}`,
  );
  console.log("─────────────────────────────────────────────────────────────");

  let totalViolations = 0;

  for (let round = 1; round <= NUM_ROUNDS; round++) {
    console.log(`\n══════════════ ROUND ${round}/${NUM_ROUNDS} ══════════════`);
    await attackFollowSpam(round);
    await attackMessageStorm(round);
    await attackRoomChurn(round);
    const violationsThisRound = await validateAfterAttack();
    totalViolations += violationsThisRound;
  }

  await cleanupStressData();

  const finishedAt = new Date();
  const durationMs = finishedAt - startedAt;

  const passed = totalViolations === 0 && results.errors.length === 0;

  console.log("\n─────────────────────────────────────────────────────────────");
  console.log(`[stress-test-harness] RESULT: ${passed ? "✅ PASSED" : "❌ FAILED"}`);
  console.log(`  total writes    : ${results.totalWrites}`);
  console.log(`  total reads     : ${results.totalReads}`);
  console.log(`  total violations: ${totalViolations}`);
  console.log(`  total errors    : ${results.errors.length}`);
  console.log(`  duration        : ${durationMs}ms`);

  if (results.errors.length > 0) {
    console.log("\n── Errors ────────────────────────────────────────────────");
    results.errors.slice(0, 10).forEach((e) => console.error(`  ${e}`));
  }

  if (totalViolations > 0) {
    console.log("\n── Violations ───────────────────────────────────────────");
    results.violations.forEach((v) =>
      console.warn(`  [${v.phase}] ${v.path} — ${v.rule}${v.detail ? ` (${v.detail})` : ""}`),
    );
    console.log("\n  Run repair scripts to fix:");
    console.log("  cd functions && npm run repair:all:apply");
  }

  process.exit(passed ? 0 : 1);
}

run().catch((err) => {
  console.error("[stress-test-harness] fatal:", err);
  process.exit(2);
});
