/* eslint-disable no-console */
/**
 * repair-messages.js
 *
 * Normalizes every document in the `messages` subcollection across ALL
 * conversations using a Firestore collectionGroup query:
 *
 *   - createdAt  — if missing, copy from sentAt; if both missing → skip (flag)
 *   - sentAt     — if missing, copy from createdAt (ensure alias is present)
 *   - conversationId — if missing, derive from the parent path segment
 *   - senderId   — if missing, log and skip (cannot safely derive)
 *
 * Documents with null timestamps or missing senderId are NEVER silently deleted
 * here — they are flagged so you can decide. Pass --purge-invalid to delete them.
 *
 * Dry-run by default. Pass --apply to write.
 *
 * Usage:
 *   node scripts/repair-messages.js
 *   node scripts/repair-messages.js --apply
 *   node scripts/repair-messages.js --apply --purge-invalid
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const APPLY = process.argv.includes("--apply");
const PURGE_INVALID = process.argv.includes("--purge-invalid");
const PAGE_SIZE = 400;

function isValidTimestamp(value) {
  if (value == null) return false;
  if (value instanceof admin.firestore.Timestamp) return true;
  if (value instanceof Date) return true;
  return false;
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

async function run() {
  const group = db.collectionGroup("messages");
  let lastDoc = null;
  let scanned = 0;
  let patched = 0;
  let skipped = 0;
  let invalid = 0;
  let purged = 0;

  console.log(
    `[repair-messages] mode=${APPLY ? "APPLY" : "DRY-RUN"} purgeInvalid=${PURGE_INVALID} pageSize=${PAGE_SIZE}`,
  );

  while (true) {
    let q = group.orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    const batch = db.batch();
    let batchCount = 0;

    for (const doc of snap.docs) {
      scanned++;
      const data = doc.data() || {};

      const hasSenderId = isNonEmptyString(data.senderId);
      const hasCreatedAt = isValidTimestamp(data.createdAt);
      const hasSentAt = isValidTimestamp(data.sentAt);

      // ── Invalid: missing senderId ────────────────────────────────────────────
      if (!hasSenderId) {
        invalid++;
        console.warn(`  [invalid:no-senderId] ${doc.ref.path}`);
        if (PURGE_INVALID && APPLY) {
          batch.delete(doc.ref);
          batchCount++;
          purged++;
        }
        continue;
      }

      // ── Invalid: both timestamps missing or null ─────────────────────────────
      if (!hasCreatedAt && !hasSentAt) {
        invalid++;
        console.warn(`  [invalid:no-timestamp] ${doc.ref.path}`);
        if (PURGE_INVALID && APPLY) {
          batch.delete(doc.ref);
          batchCount++;
          purged++;
        }
        continue;
      }

      const updates = {};

      // ── createdAt ────────────────────────────────────────────────────────────
      if (!hasCreatedAt && hasSentAt) {
        updates.createdAt = data.sentAt;
      }

      // ── sentAt ───────────────────────────────────────────────────────────────
      if (!hasSentAt && hasCreatedAt) {
        updates.sentAt = data.createdAt;
      }

      // ── conversationId ───────────────────────────────────────────────────────
      // Path: conversations/{conversationId}/messages/{messageId}
      if (!isNonEmptyString(data.conversationId)) {
        const pathSegments = doc.ref.path.split("/");
        // pathSegments[0] = 'conversations', pathSegments[1] = conversationId
        if (pathSegments.length >= 2 && isNonEmptyString(pathSegments[1])) {
          updates.conversationId = pathSegments[1];
        }
      }

      if (Object.keys(updates).length === 0) {
        skipped++;
        continue;
      }

      patched++;
      console.log(`  [patch] ${doc.ref.path}`, updates);
      if (APPLY) {
        batch.update(doc.ref, updates);
        batchCount++;
      }
    }

    if (APPLY && batchCount > 0) {
      await batch.commit();
      console.log(`  [commit] ${batchCount} writes committed`);
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < PAGE_SIZE) break;
  }

  console.log(
    `\n[repair-messages] done — scanned=${scanned} patched=${patched} skipped=${skipped} invalid=${invalid} purged=${purged}`,
  );
  if (!APPLY && (patched > 0 || (PURGE_INVALID && invalid > 0))) {
    console.log("[repair-messages] Re-run with --apply to write changes.");
  }
  if (!PURGE_INVALID && invalid > 0) {
    console.log(
      `[repair-messages] ${invalid} invalid docs flagged. Re-run with --purge-invalid --apply to delete them.`,
    );
  }
}

run().catch((err) => {
  console.error("[repair-messages] fatal:", err);
  process.exit(1);
});
