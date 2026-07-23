/* eslint-disable no-console */
/**
 * repair-follows.js
 *
 * Normalises the follow graph across three surfaces:
 *
 *   1. `follows/{id}` flat collection
 *      - Doc ID format: `{followerUserId}_{followedUserId}`
 *      - Required fields: followerUserId, followedUserId, createdAt
 *      - Repair: if fields missing, derive from doc ID; add createdAt if absent.
 *
 *   2. `users/{uid}/followers/{followerId}` subcollection symmetry
 *      - For every `follows` doc, ensure the follower entry exists.
 *
 *   3. `users/{uid}/following/{followedId}` subcollection symmetry
 *      - For every `follows` doc, ensure the following entry exists.
 *
 * Symmetry check: if A follows B in `follows/`, both
 *   users/B/followers/A  and  users/A/following/B  must exist.
 *
 * This script does NOT delete orphaned subcollection entries that have no
 * corresponding `follows/` doc — that is a separate purge pass.
 *
 * Dry-run by default. Pass --apply to write.
 *
 * Usage:
 *   node scripts/repair-follows.js
 *   node scripts/repair-follows.js --apply
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const APPLY = process.argv.includes("--apply");
const PAGE_SIZE = 400;

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isValidTimestamp(value) {
  if (value == null) return false;
  if (value instanceof admin.firestore.Timestamp) return true;
  if (value instanceof Date) return true;
  return false;
}

/**
 * Parse followerUserId and followedUserId from the flat doc ID.
 * Format: {followerUserId}_{followedUserId}
 * Note: UIDs can contain underscores themselves (Firebase UIDs don't, but be safe).
 * We split only on the FIRST underscore — Firebase UIDs are alphanumeric, so this
 * is safe for Firebase Auth UIDs.
 */
function parseDocId(docId) {
  const idx = docId.indexOf("_");
  if (idx === -1) return null;
  return {
    followerUserId: docId.substring(0, idx),
    followedUserId: docId.substring(idx + 1),
  };
}

async function run() {
  const col = db.collection("follows");
  let lastDoc = null;
  let scanned = 0;
  let flatPatched = 0;
  let followersMissing = 0;
  let followingMissing = 0;
  let skipped = 0;

  console.log(`[repair-follows] mode=${APPLY ? "APPLY" : "DRY-RUN"} pageSize=${PAGE_SIZE}`);

  while (true) {
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    // Collect symmetry writes separately (they touch different collections).
    const symmetryBatch = db.batch();
    let symmetryOps = 0;
    const flatBatch = db.batch();
    let flatOps = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};

      // ── Derive followerUserId / followedUserId ────────────────────────────
      let followerUserId = isNonEmptyString(data.followerUserId)
        ? data.followerUserId.trim()
        : null;
      let followedUserId = isNonEmptyString(data.followedUserId)
        ? data.followedUserId.trim()
        : null;

      // Fall back to parsing the doc ID.
      if (!followerUserId || !followedUserId) {
        const parsed = parseDocId(doc.id);
        if (!parsed) {
          console.warn(`  [skip:unparseable-id] follows/${doc.id}`);
          skipped++;
          continue;
        }
        followerUserId = followerUserId || parsed.followerUserId;
        followedUserId = followedUserId || parsed.followedUserId;
      }

      if (!isNonEmptyString(followerUserId) || !isNonEmptyString(followedUserId)) {
        console.warn(`  [skip:empty-ids] follows/${doc.id}`);
        skipped++;
        continue;
      }

      // ── Repair flat follows doc ───────────────────────────────────────────
      const flatUpdates = {};
      if (!isNonEmptyString(data.followerUserId)) {
        flatUpdates.followerUserId = followerUserId;
      }
      if (!isNonEmptyString(data.followedUserId)) {
        flatUpdates.followedUserId = followedUserId;
      }
      if (!isValidTimestamp(data.createdAt)) {
        flatUpdates.createdAt = admin.firestore.FieldValue.serverTimestamp();
      }

      if (Object.keys(flatUpdates).length > 0) {
        flatPatched++;
        console.log(`  [patch:flat] follows/${doc.id}`, flatUpdates);
        if (APPLY) {
          flatBatch.update(doc.ref, flatUpdates);
          flatOps++;
        }
      }

      // ── Symmetry: users/{followedUserId}/followers/{followerUserId} ───────
      const followerEntry = db
        .collection("users")
        .doc(followedUserId)
        .collection("followers")
        .doc(followerUserId);

      const followerSnap = await followerEntry.get();
      if (!followerSnap.exists) {
        followersMissing++;
        console.log(`  [missing:follower] users/${followedUserId}/followers/${followerUserId}`);
        if (APPLY) {
          symmetryBatch.set(followerEntry, {
            userId: followerUserId,
            createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          symmetryOps++;
        }
      }

      // ── Symmetry: users/{followerUserId}/following/{followedUserId} ───────
      const followingEntry = db
        .collection("users")
        .doc(followerUserId)
        .collection("following")
        .doc(followedUserId);

      const followingSnap = await followingEntry.get();
      if (!followingSnap.exists) {
        followingMissing++;
        console.log(`  [missing:following] users/${followerUserId}/following/${followedUserId}`);
        if (APPLY) {
          symmetryBatch.set(followingEntry, {
            userId: followedUserId,
            createdAt: data.createdAt || admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
          symmetryOps++;
        }
      }

      // Flush symmetry batch early if near limit.
      if (symmetryOps >= 450) {
        if (APPLY) {
          await symmetryBatch.commit();
          console.log("  [commit] symmetry batch flush (450 ops)");
        }
        symmetryOps = 0;
      }
    }

    if (APPLY) {
      if (flatOps > 0) {
        await flatBatch.commit();
        console.log(`  [commit:flat] ${flatOps} follows doc writes`);
      }
      if (symmetryOps > 0) {
        await symmetryBatch.commit();
        console.log(`  [commit:symmetry] ${symmetryOps} subcollection writes`);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < PAGE_SIZE) break;
  }

  console.log(
    `\n[repair-follows] done` +
    ` — scanned=${scanned}` +
    ` | flat patched=${flatPatched}` +
    ` | followers missing=${followersMissing}` +
    ` | following missing=${followingMissing}` +
    ` | skipped=${skipped}`,
  );
  if (!APPLY && (flatPatched + followersMissing + followingMissing) > 0) {
    console.log("[repair-follows] Re-run with --apply to write changes.");
  }
}

run().catch((err) => {
  console.error("[repair-follows] fatal:", err);
  process.exit(1);
});
