/* eslint-disable no-console */
/**
 * validate-firestore-truth.js
 *
 * One-shot production truth validator.
 * Queries Firestore, collects violations, prints a structured report,
 * and exits non-zero if ANY violation is found.
 *
 * Designed to run:
 *   - manually before a production deploy
 *   - in CI after a migration pass
 *   - as a cron health check
 *
 * Usage:
 *   node scripts/validate-firestore-truth.js
 *   node scripts/validate-firestore-truth.js --json          # machine-readable output
 *   node scripts/validate-firestore-truth.js --sample 200   # per-collection sample size
 *
 * Exit codes:
 *   0  — all checks passed
 *   1  — violations found (critical)
 *   2  — script error / Firestore unreachable
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// ── CLI flags ────────────────────────────────────────────────────────────────
const JSON_MODE = process.argv.includes("--json");
const SAMPLE_IDX = process.argv.indexOf("--sample");
const SAMPLE = SAMPLE_IDX !== -1 ? parseInt(process.argv[SAMPLE_IDX + 1], 10) || 500 : 500;

// ── Violation registry ───────────────────────────────────────────────────────
const violations = {
  conversations: [],
  messages: [],
  rooms: [],
  roomParticipants: [],
  follows: [],
  followersSymmetry: [],
  followingSymmetry: [],
  webrtcSessions: [],
  webrtcParticipants: [],
};

let totalViolations = 0;
let totalScanned = 0;

function isValidTimestamp(value) {
  if (value == null) return false;
  if (value instanceof admin.firestore.Timestamp) return true;
  if (value instanceof Date) return true;
  return false;
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function addViolation(bucket, docPath, rule, details) {
  violations[bucket].push({path: docPath, rule, details: details || null});
  totalViolations++;
}

// ── SECTION 1: Conversations ─────────────────────────────────────────────────
async function checkConversations() {
  const col = db.collection("conversations");
  let lastDoc = null;
  let scanned = 0;

  while (scanned < SAMPLE) {
    const remaining = SAMPLE - scanned;
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(Math.min(remaining, 400));
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned++;
      totalScanned++;
      const d = doc.data() || {};
      const p = `conversations/${doc.id}`;

      if (!Array.isArray(d.participantIds) || d.participantIds.length === 0) {
        addViolation("conversations", p, "missing_participantIds",
          `got: ${JSON.stringify(d.participantIds)}`);
      }

      if (!isValidTimestamp(d.lastMessageAt) && !isValidTimestamp(d.createdAt)) {
        addViolation("conversations", p, "missing_timestamp",
          "both lastMessageAt and createdAt are absent");
      }

      if (typeof d.status !== "string" || d.status.trim() === "") {
        addViolation("conversations", p, "missing_status",
          `got: ${JSON.stringify(d.status)}`);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 400) break;
  }

  return scanned;
}

// ── SECTION 2: Messages (collectionGroup sample) ─────────────────────────────
async function checkMessages() {
  const group = db.collectionGroup("messages");
  let lastDoc = null;
  let scanned = 0;

  while (scanned < SAMPLE) {
    const remaining = SAMPLE - scanned;
    let q = group.orderBy(admin.firestore.FieldPath.documentId()).limit(Math.min(remaining, 400));
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned++;
      totalScanned++;
      const d = doc.data() || {};
      const p = doc.ref.path;

      if (!isNonEmptyString(d.senderId)) {
        addViolation("messages", p, "missing_senderId", null);
      }

      const hasCreatedAt = isValidTimestamp(d.createdAt);
      const hasSentAt = isValidTimestamp(d.sentAt);
      if (!hasCreatedAt && !hasSentAt) {
        addViolation("messages", p, "missing_timestamp",
          "both createdAt and sentAt are absent or null");
      }

      // sentAt and createdAt must be aliases of each other (within 1 second).
      if (hasCreatedAt && hasSentAt) {
        const createdMs = d.createdAt instanceof admin.firestore.Timestamp
          ? d.createdAt.toMillis()
          : d.createdAt.getTime();
        const sentMs = d.sentAt instanceof admin.firestore.Timestamp
          ? d.sentAt.toMillis()
          : d.sentAt.getTime();
        if (Math.abs(createdMs - sentMs) > 1000) {
          addViolation("messages", p, "timestamp_mismatch",
            `createdAt=${createdMs} sentAt=${sentMs} delta=${Math.abs(createdMs - sentMs)}ms`);
        }
      }

      if (!isNonEmptyString(d.conversationId)) {
        addViolation("messages", p, "missing_conversationId", null);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 400) break;
  }

  return scanned;
}

// ── SECTION 3: Rooms ─────────────────────────────────────────────────────────
async function checkRooms() {
  const col = db.collection("rooms");
  let lastDoc = null;
  let scanned = 0;
  let participantsScanned = 0;

  while (scanned < SAMPLE) {
    const remaining = SAMPLE - scanned;
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(Math.min(remaining, 200));
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned++;
      totalScanned++;
      const d = doc.data() || {};
      const p = `rooms/${doc.id}`;

      if (typeof d.isAdult !== "boolean") {
        addViolation("rooms", p, "isAdult_not_boolean",
          `got: ${JSON.stringify(d.isAdult)} (${typeof d.isAdult})`);
      }

      if (!isNonEmptyString(d.hostId) && !isNonEmptyString(d.ownerId)) {
        addViolation("rooms", p, "missing_hostId_and_ownerId", null);
      }

      if (!Array.isArray(d.stageUserIds)) {
        addViolation("rooms", p, "stageUserIds_not_array",
          `got: ${typeof d.stageUserIds}`);
      }

      if (!Array.isArray(d.audienceUserIds)) {
        addViolation("rooms", p, "audienceUserIds_not_array",
          `got: ${typeof d.audienceUserIds}`);
      }

      // Sample participants subcollection (first 50 per room)
      const participantsSnap = await doc.ref.collection("participants").limit(50).get();
      for (const pDoc of participantsSnap.docs) {
        participantsScanned++;
        totalScanned++;
        const pd = pDoc.data() || {};
        const pp = pDoc.ref.path;

        if (!isNonEmptyString(pd.userId)) {
          addViolation("roomParticipants", pp, "missing_userId", null);
        }

        if (!isValidTimestamp(pd.joinedAt)) {
          addViolation("roomParticipants", pp, "missing_joinedAt", null);
        }

        const allowedRoles = new Set([
          "host", "cohost", "moderator", "trusted_speaker",
          "stage", "audience", "owner", "mod", "member",
        ]);
        if (!allowedRoles.has(pd.role)) {
          addViolation("roomParticipants", pp, "invalid_role",
            `got: ${JSON.stringify(pd.role)}`);
        }
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 200) break;
  }

  return {scanned, participantsScanned};
}

// ── SECTION 4: Follows + symmetry ────────────────────────────────────────────
async function checkFollows() {
  const col = db.collection("follows");
  let lastDoc = null;
  let scanned = 0;
  const FOLLOWS_SAMPLE = Math.min(SAMPLE, 300); // symmetry checks are expensive

  while (scanned < FOLLOWS_SAMPLE) {
    const remaining = FOLLOWS_SAMPLE - scanned;
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(Math.min(remaining, 200));
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    // Check symmetry in parallel batches of 20 to avoid saturating Firestore.
    const docs = snap.docs;
    for (let i = 0; i < docs.length; i += 20) {
      const chunk = docs.slice(i, i + 20);
      await Promise.all(chunk.map(async (doc) => {
        scanned++;
        totalScanned++;
        const d = doc.data() || {};
        const p = `follows/${doc.id}`;

        const follower = isNonEmptyString(d.followerUserId) ? d.followerUserId.trim() : null;
        const followed = isNonEmptyString(d.followedUserId) ? d.followedUserId.trim() : null;

        if (!follower || !followed) {
          addViolation("follows", p, "missing_ids",
            `followerUserId=${JSON.stringify(d.followerUserId)} followedUserId=${JSON.stringify(d.followedUserId)}`);
          return; // can't check symmetry without IDs
        }

        if (!isValidTimestamp(d.createdAt)) {
          addViolation("follows", p, "missing_createdAt", null);
        }

        // Symmetry: users/{followed}/followers/{follower}
        const followerEntry = db
          .collection("users").doc(followed)
          .collection("followers").doc(follower);
        const followerSnap = await followerEntry.get();
        if (!followerSnap.exists) {
          addViolation("followersSymmetry",
            `users/${followed}/followers/${follower}`,
            "missing_follower_entry",
            `follows doc: ${p}`);
        }

        // Symmetry: users/{follower}/following/{followed}
        const followingEntry = db
          .collection("users").doc(follower)
          .collection("following").doc(followed);
        const followingSnap = await followingEntry.get();
        if (!followingSnap.exists) {
          addViolation("followingSymmetry",
            `users/${follower}/following/${followed}`,
            "missing_following_entry",
            `follows doc: ${p}`);
        }
      }));
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 200) break;
  }

  return scanned;
}

// ── SECTION 5: WebRTC Sessions ───────────────────────────────────────────────
async function checkWebRtcSessions() {
  const col = db.collection("webrtc_sessions");
  let lastDoc = null;
  let scanned = 0;
  let participantsScanned = 0;

  while (scanned < SAMPLE) {
    const remaining = SAMPLE - scanned;
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(Math.min(remaining, 200));
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      scanned++;
      totalScanned++;
      const d = doc.data() || {};
      const p = `webrtc_sessions/${doc.id}`;

      // Check if there is an active host or session owner
      if (d.hostId && typeof d.hostId !== "string") {
        addViolation("webrtcSessions", p, "invalid_hostId", `got: ${typeof d.hostId}`);
      }

      // Sample participants subcollection
      const participantsSnap = await doc.ref.collection("participants").limit(50).get();
      for (const pDoc of participantsSnap.docs) {
        participantsScanned++;
        totalScanned++;
        const pd = pDoc.data() || {};
        const pp = pDoc.ref.path;

        if (!isNonEmptyString(pd.userId) && !isNonEmptyString(pDoc.id)) {
          addViolation("webrtcParticipants", pp, "missing_userId", null);
        }

        if (pd.joinedAt && !isValidTimestamp(pd.joinedAt)) {
          addViolation("webrtcParticipants", pp, "invalid_joinedAt", null);
        }
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < 200) break;
  }

  return {scanned, participantsScanned};
}

// ── MAIN ─────────────────────────────────────────────────────────────────────
async function run() {
  const startedAt = new Date();
  console.log(`[validate-firestore-truth] started=${startedAt.toISOString()} sample=${SAMPLE}`);
  console.log("─────────────────────────────────────────────────────────────");

  console.log("[1/5] Checking conversations…");
  const convScanned = await checkConversations();
  console.log(`      scanned=${convScanned} violations=${violations.conversations.length}`);

  console.log("[2/5] Checking messages…");
  const msgScanned = await checkMessages();
  console.log(`      scanned=${msgScanned} violations=${violations.messages.length}`);

  console.log("[3/5] Checking rooms + participants…");
  const {scanned: roomScanned, participantsScanned} = await checkRooms();
  console.log(`      rooms scanned=${roomScanned} participants scanned=${participantsScanned}`);
  console.log(`      room violations=${violations.rooms.length} participant violations=${violations.roomParticipants.length}`);

  console.log("[4/5] Checking follows + symmetry…");
  const followsScanned = await checkFollows();
  console.log(`      scanned=${followsScanned} flat violations=${violations.follows.length}`);
  console.log(`      follower symmetry violations=${violations.followersSymmetry.length}`);
  console.log(`      following symmetry violations=${violations.followingSymmetry.length}`);

  console.log("[5/5] Checking WebRTC sessions + participants…");
  const {scanned: webrtcScanned, participantsScanned: webrtcParticipantsScanned} = await checkWebRtcSessions();
  console.log(`      sessions scanned=${webrtcScanned} participants scanned=${webrtcParticipantsScanned}`);
  console.log(`      session violations=${violations.webrtcSessions.length} participant violations=${violations.webrtcParticipants.length}`);

  const finishedAt = new Date();
  const durationMs = finishedAt - startedAt;

  // ── Build report ──────────────────────────────────────────────────────────
  const report = {
    schemaVersion: "1.0.0",
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs,
    sampleSize: SAMPLE,
    totalScanned,
    totalViolations,
    passed: totalViolations === 0,
    summary: {
      conversations: {scanned: convScanned, violations: violations.conversations.length},
      messages: {scanned: msgScanned, violations: violations.messages.length},
      rooms: {scanned: roomScanned, violations: violations.rooms.length},
      roomParticipants: {scanned: participantsScanned, violations: violations.roomParticipants.length},
      follows: {scanned: followsScanned, violations: violations.follows.length},
      followersSymmetry: {violations: violations.followersSymmetry.length},
      followingSymmetry: {violations: violations.followingSymmetry.length},
      webrtcSessions: {scanned: webrtcScanned, violations: violations.webrtcSessions.length},
      webrtcParticipants: {scanned: webrtcParticipantsScanned, violations: violations.webrtcParticipants.length},
    },
    violations,
  };

  // ── Write JSON report ─────────────────────────────────────────────────────
  const reportDir = path.join(__dirname, "..", "..", "tools", "reports");
  if (!fs.existsSync(reportDir)) {
    fs.mkdirSync(reportDir, {recursive: true});
  }
  const reportPath = path.join(reportDir, "firestore_truth_validation.json");
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  // ── Console output ────────────────────────────────────────────────────────
  console.log("─────────────────────────────────────────────────────────────");

  if (JSON_MODE) {
    process.stdout.write(JSON.stringify(report, null, 2) + "\n");
  } else {
    console.log(`\n[validate-firestore-truth] RESULT: ${totalViolations === 0 ? "✅ PASSED" : "❌ FAILED"}`);
    console.log(`  total scanned : ${totalScanned}`);
    console.log(`  total violations : ${totalViolations}`);
    console.log(`  duration : ${durationMs}ms`);
    console.log(`  report written : ${reportPath}`);

    if (totalViolations > 0) {
      console.log("\n── Violation summary ─────────────────────────────────────");
      for (const [bucket, list] of Object.entries(violations)) {
        if (list.length === 0) continue;
        console.log(`  ${bucket}: ${list.length} violation(s)`);
        // Print first 5 per bucket to keep output readable
        const preview = list.slice(0, 5);
        for (const v of preview) {
          console.log(`    ↳ [${v.rule}] ${v.path}${v.details ? ` — ${v.details}` : ""}`);
        }
        if (list.length > 5) {
          console.log(`    … and ${list.length - 5} more (see report file)`);
        }
      }
      console.log("\n  ⚠️  Run the repair scripts to fix violations before deploying.");
      console.log("     npm run repair:all:apply   (from functions/)");
    }
  }

  process.exit(totalViolations > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error("[validate-firestore-truth] fatal:", err);
  process.exit(2);
});
