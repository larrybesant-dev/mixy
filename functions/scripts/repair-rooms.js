/* eslint-disable no-console */
/**
 * repair-rooms.js
 *
 * Normalizes room documents and their participants subcollection:
 *
 * rooms/{roomId}:
 *   - isAdult    — coerced to boolean (any truthy string/number → true)
 *   - hostId     — if missing but ownerId present, copy ownerId → hostId
 *   - ownerId    — if missing but hostId present, copy hostId → ownerId
 *                  (Firestore rules check both; both must exist)
 *   - stageUserIds    — guaranteed non-null array
 *   - audienceUserIds — guaranteed non-null array
 *
 * rooms/{roomId}/participants/{uid}:
 *   - userId   — if missing, derive from the document ID (which equals uid)
 *   - joinedAt — if missing, fall back to createdAt → serverTimestamp sentinel
 *   - role     — if missing, defaults to 'audience'
 *
 * Optional orphan prune:
 *   - If a room has neither hostId nor ownerId and no participants/members/
 *     speakers/messages plus empty stage/audience arrays, it can be deleted
 *     safely as an orphan stub using --prune-orphaned-hostless.
 *
 * Dry-run by default. Pass --apply to write.
 *
 * Usage:
 *   node scripts/repair-rooms.js
 *   node scripts/repair-rooms.js --apply
 *   node scripts/repair-rooms.js --apply --prune-orphaned-hostless
 */

const admin = require("firebase-admin");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const APPLY = process.argv.includes("--apply");
const PRUNE_ORPHANED_HOSTLESS = process.argv.includes("--prune-orphaned-hostless");
const PAGE_SIZE = 300;
const ALLOWED_PARTICIPANT_ROLES = new Set([
  "host", "cohost", "moderator", "trusted_speaker", "stage", "audience",
  "owner", "mod", "member",
]);

function isValidTimestamp(value) {
  if (value == null) return false;
  if (value instanceof admin.firestore.Timestamp) return true;
  if (value instanceof Date) return true;
  return false;
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function coerceBool(value) {
  if (typeof value === "boolean") return value;
  if (typeof value === "number") return value !== 0;
  if (typeof value === "string") {
    const n = value.trim().toLowerCase();
    return n === "true" || n === "1" || n === "yes";
  }
  return false;
}

function toStringArray(raw) {
  if (!Array.isArray(raw)) return [];
  return [...new Set(raw.filter((v) => typeof v === "string" && v.trim().length > 0).map((v) => v.trim()))];
}

function resolveHostCandidate(data, participantDocs) {
  const directCandidates = [
    data.hostId,
    data.ownerId,
    data.hostUserId,
    data.ownerUserId,
    data.createdBy,
    data.creatorId,
    data.userId,
  ];

  for (const candidate of directCandidates) {
    if (isNonEmptyString(candidate)) {
      return candidate.trim();
    }
  }

  // Prefer explicit host/owner role in participants when available.
  for (const pDoc of participantDocs) {
    const pd = pDoc.data() || {};
    const role = typeof pd.role === "string" ? pd.role.trim().toLowerCase() : "";
    if (role === "host" || role === "owner") {
      if (isNonEmptyString(pd.userId)) {
        return pd.userId.trim();
      }
      if (isNonEmptyString(pDoc.id)) {
        return pDoc.id.trim();
      }
    }
  }

  // Fallback to room arrays in deterministic order.
  const stageUserIds = toStringArray(data.stageUserIds);
  if (stageUserIds.length > 0) {
    return stageUserIds[0];
  }

  const audienceUserIds = toStringArray(data.audienceUserIds);
  if (audienceUserIds.length > 0) {
    return audienceUserIds[0];
  }

  // Last fallback: any participant user id.
  for (const pDoc of participantDocs) {
    const pd = pDoc.data() || {};
    if (isNonEmptyString(pd.userId)) {
      return pd.userId.trim();
    }
    if (isNonEmptyString(pDoc.id)) {
      return pDoc.id.trim();
    }
  }

  return null;
}

async function repairRoomDoc(doc, batch) {
  const data = doc.data() || {};
  const updates = {};

  // ── isAdult (must be boolean) ────────────────────────────────────────────
  if (typeof data.isAdult !== "boolean") {
    updates.isAdult = coerceBool(data.isAdult);
  }

  // ── hostId / ownerId cross-fill ──────────────────────────────────────────
  const hasHostId = isNonEmptyString(data.hostId);
  const hasOwnerId = isNonEmptyString(data.ownerId);
  if (hasHostId && !hasOwnerId) {
    updates.ownerId = data.hostId.trim();
  } else if (!hasHostId && hasOwnerId) {
    updates.hostId = data.ownerId.trim();
  }

  // ── stageUserIds / audienceUserIds ───────────────────────────────────────
  if (!Array.isArray(data.stageUserIds)) {
    updates.stageUserIds = [];
  }
  if (!Array.isArray(data.audienceUserIds)) {
    updates.audienceUserIds = [];
  }

  if (Object.keys(updates).length > 0) {
    console.log(`  [patch:room] rooms/${doc.id}`, updates);
    if (APPLY) {
      batch.update(doc.ref, updates);
    }
    return true;
  }
  return false;
}

async function repairParticipantDoc(doc, batch) {
  const data = doc.data() || {};
  const updates = {};

  // ── userId — derive from doc ID if missing ───────────────────────────────
  if (!isNonEmptyString(data.userId)) {
    const derivedUid = doc.id;
    if (isNonEmptyString(derivedUid)) {
      updates.userId = derivedUid;
    }
  }

  // ── joinedAt — fall back to createdAt or use server timestamp ────────────
  if (!isValidTimestamp(data.joinedAt)) {
    if (isValidTimestamp(data.createdAt)) {
      updates.joinedAt = data.createdAt;
    } else {
      updates.joinedAt = admin.firestore.FieldValue.serverTimestamp();
    }
  }

  // ── role — default to 'audience' if missing or unknown ──────────────────
  const role = typeof data.role === "string" ? data.role.trim() : "";
  if (!ALLOWED_PARTICIPANT_ROLES.has(role)) {
    updates.role = "audience";
  }

  if (Object.keys(updates).length > 0) {
    console.log(`  [patch:participant] ${doc.ref.path}`, updates);
    if (APPLY) {
      batch.update(doc.ref, updates);
    }
    return true;
  }
  return false;
}

async function run() {
  const col = db.collection("rooms");
  let lastDoc = null;
  let roomsScanned = 0;
  let roomsPatched = 0;
  let participantsScanned = 0;
  let participantsPatched = 0;
  let roomsDeleted = 0;

  console.log(`[repair-rooms] mode=${APPLY ? "APPLY" : "DRY-RUN"} pageSize=${PAGE_SIZE}`);

  while (true) {
    let q = col.orderBy(admin.firestore.FieldPath.documentId()).limit(PAGE_SIZE);
    if (lastDoc) q = q.startAfter(lastDoc);

    const snap = await q.get();
    if (snap.empty) break;

    for (const roomDoc of snap.docs) {
      roomsScanned++;
      const participantsSnap = await roomDoc.ref.collection("participants").get();

      // Use separate batches per room to stay well under the 500-op Firestore limit.
      const batch = db.batch();
      let batchOps = 0;

      const roomData = roomDoc.data() || {};
      const hasHostId = isNonEmptyString(roomData.hostId);
      const hasOwnerId = isNonEmptyString(roomData.ownerId);
      if (!hasHostId && !hasOwnerId) {
        const candidate = resolveHostCandidate(roomData, participantsSnap.docs);
        if (candidate) {
          roomData.hostId = candidate;
          roomData.ownerId = candidate;
        } else {
          const stageUserIds = toStringArray(roomData.stageUserIds);
          const audienceUserIds = toStringArray(roomData.audienceUserIds);

          const roomRef = roomDoc.ref;
          const [messagesSnap, membersSnap, speakersSnap] = await Promise.all([
            roomRef.collection("messages").limit(1).get(),
            roomRef.collection("members").limit(1).get(),
            roomRef.collection("speakers").limit(1).get(),
          ]);

          const canPruneAsOrphan =
            participantsSnap.empty &&
            membersSnap.empty &&
            speakersSnap.empty &&
            messagesSnap.empty &&
            stageUserIds.length === 0 &&
            audienceUserIds.length === 0;

          if (canPruneAsOrphan && PRUNE_ORPHANED_HOSTLESS) {
            console.log(`  [delete:orphan-room] rooms/${roomDoc.id}`);
            if (APPLY) {
              batch.delete(roomRef);
            }
            roomsDeleted++;
            batchOps++;
          } else {
            console.warn(`  [skip:room-host-owner-unresolvable] rooms/${roomDoc.id}`);
          }
        }
      }

      const roomPatched = await repairRoomDoc(
        {
          id: roomDoc.id,
          ref: roomDoc.ref,
          data: () => roomData,
        },
        batch,
      );
      if (roomPatched) {
        roomsPatched++;
        batchOps++;
      }

      // ── participants subcollection ──────────────────────────────────────
      for (const pDoc of participantsSnap.docs) {
        participantsScanned++;
        const pPatched = await repairParticipantDoc(pDoc, batch);
        if (pPatched) {
          participantsPatched++;
          batchOps++;
        }

        // Flush batch early if approaching Firestore's 500-op limit.
        if (batchOps >= 450) {
          if (APPLY) {
            await batch.commit();
            console.log(`  [commit] 450-op flush`);
          }
          batchOps = 0;
        }
      }

      if (APPLY && batchOps > 0) {
        await batch.commit();
        console.log(`  [commit] ${batchOps} writes committed for room ${roomDoc.id}`);
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.docs.length < PAGE_SIZE) break;
  }

  console.log(
    `\n[repair-rooms] done` +
    ` — rooms scanned=${roomsScanned} patched=${roomsPatched}` +
    ` | participants scanned=${participantsScanned} patched=${participantsPatched}` +
    ` | rooms deleted=${roomsDeleted}`,
  );
  if (!APPLY && (roomsPatched + participantsPatched) > 0) {
    console.log("[repair-rooms] Re-run with --apply to write changes.");
  }
}

run().catch((err) => {
  console.error("[repair-rooms] fatal:", err);
  process.exit(1);
});
