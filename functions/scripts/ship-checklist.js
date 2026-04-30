/* eslint-disable no-console */
/**
 * ship-checklist.js
 *
 * Pre-launch readiness audit — runs every check in sequence and produces a
 * structured PASS / FAIL / WARN report. Exits non-zero if any FAIL is present.
 *
 * Categories:
 *   1. Environment   — Node version, Firebase admin reachability
 *   2. Data integrity — Firestore truth validation (inline summary)
 *   3. Architecture  — provider duplication scan on the lib/ source tree
 *   4. Rules         — firestore.rules sanity checks (key collections covered)
 *   5. Deploy gates  — deploy.ps1 and firebase.json gate presence
 *   6. Security      — storage.rules, auth config, known insecure patterns
 *
 * Usage:
 *   node scripts/ship-checklist.js
 *   node scripts/ship-checklist.js --json
 */

const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

const JSON_MODE = process.argv.includes("--json");
const WORKSPACE_ROOT = path.resolve(__dirname, "..", "..");
const LIB_DIR = path.join(WORKSPACE_ROOT, "lib");
const FUNCTIONS_DIR = path.join(WORKSPACE_ROOT, "functions");

// ── Check registry ────────────────────────────────────────────────────────────
const checks = [];
let failCount = 0;
let warnCount = 0;

function addCheck(category, name, status, detail) {
  if (status === "FAIL") failCount++;
  if (status === "WARN") warnCount++;
  checks.push({category, name, status, detail: detail || null});

  if (!JSON_MODE) {
    const icon = status === "PASS" ? "✅" : status === "WARN" ? "⚠️ " : "❌";
    const line = `  ${icon} [${category}] ${name}`;
    if (detail && status !== "PASS") {
      console.log(line);
      console.log(`       ${detail}`);
    } else {
      console.log(line);
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────
function fileExists(rel) {
  return fs.existsSync(path.join(WORKSPACE_ROOT, rel));
}

function fileContains(rel, pattern) {
  if (!fileExists(rel)) return false;
  return fs.readFileSync(path.join(WORKSPACE_ROOT, rel), "utf8").includes(pattern);
}

function grepLib(pattern, opts = {}) {
  const hits = [];
  const ext = opts.ext || ".dart";
  function walk(dir) {
    if (!fs.existsSync(dir)) return;
    for (const entry of fs.readdirSync(dir, {withFileTypes: true})) {
      const full = path.join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(full);
      } else if (entry.isFile() && entry.name.endsWith(ext)) {
        const lines = fs.readFileSync(full, "utf8").split("\n");
        lines.forEach((line, i) => {
          const trimmed = line.trim();
          if (trimmed.startsWith("//") || trimmed.startsWith("*")) return;
          if (typeof pattern === "string" ? trimmed.includes(pattern) : pattern.test(trimmed)) {
            hits.push(`${path.relative(WORKSPACE_ROOT, full)}:${i + 1}`);
          }
        });
      }
    }
  }
  walk(opts.dir || LIB_DIR);
  return hits;
}

// ── Section 1: Environment ────────────────────────────────────────────────────
async function checkEnvironment() {
  // Node version
  const [major] = process.versions.node.split(".").map(Number);
  addCheck("env", "Node ≥ 18", major >= 18 ? "PASS" : "FAIL",
    major < 18 ? `found Node ${process.versions.node}` : null);

  // firebase-admin reachability
  try {
    await db.collection("_healthcheck_").limit(1).get();
    addCheck("env", "Firestore reachable", "PASS");
  } catch (err) {
    addCheck("env", "Firestore reachable", "FAIL", err.message);
  }

  // pubspec.yaml exists
  addCheck("env", "pubspec.yaml present", fileExists("pubspec.yaml") ? "PASS" : "FAIL");

  // firebase.json present
  addCheck("env", "firebase.json present", fileExists("firebase.json") ? "PASS" : "FAIL");
}

// ── Section 2: Data integrity ─────────────────────────────────────────────────
async function checkDataIntegrity() {
  // Quick Firestore sample: conversations
  let convViolations = 0;
  try {
    const snap = await db.collection("conversations").limit(100).get();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (!Array.isArray(d.participantIds) || d.participantIds.length === 0) convViolations++;
      if (!d.lastMessageAt && !d.createdAt) convViolations++;
    }
    addCheck("data", `Conversations sample (${snap.size} docs)`,
      convViolations === 0 ? "PASS" : "FAIL",
      convViolations > 0 ? `${convViolations} schema violations — run npm run repair:conversations:apply` : null);
  } catch (err) {
    addCheck("data", "Conversations sample", "WARN", `query failed: ${err.message}`);
  }

  // Messages collectionGroup — sample 50
  let msgViolations = 0;
  try {
    const snap = await db.collectionGroup("messages").limit(50).get();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (!d.senderId) msgViolations++;
      if (!d.createdAt && !d.sentAt) msgViolations++;
    }
    addCheck("data", `Messages sample (${snap.size} docs)`,
      msgViolations === 0 ? "PASS" : "FAIL",
      msgViolations > 0 ? `${msgViolations} violations — run npm run repair:messages:apply` : null);
  } catch (err) {
    addCheck("data", "Messages sample", "WARN", `query failed: ${err.message}`);
  }

  // Rooms — isAdult must be boolean
  let roomViolations = 0;
  try {
    const snap = await db.collection("rooms").limit(50).get();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (typeof d.isAdult !== "boolean") roomViolations++;
      if (!d.hostId && !d.ownerId) roomViolations++;
    }
    addCheck("data", `Rooms sample (${snap.size} docs)`,
      roomViolations === 0 ? "PASS" : "FAIL",
      roomViolations > 0 ? `${roomViolations} violations — run npm run repair:rooms:apply` : null);
  } catch (err) {
    addCheck("data", "Rooms sample", "WARN", `query failed: ${err.message}`);
  }

  // Follows — sample 50
  let followViolations = 0;
  try {
    const snap = await db.collection("follows").limit(50).get();
    for (const doc of snap.docs) {
      const d = doc.data() || {};
      if (!d.followerUserId || !d.followedUserId) followViolations++;
    }
    addCheck("data", `Follows sample (${snap.size} docs)`,
      followViolations === 0 ? "PASS" : "FAIL",
      followViolations > 0 ? `${followViolations} violations — run npm run repair:follows:apply` : null);
  } catch (err) {
    addCheck("data", "Follows sample", "WARN", `query failed: ${err.message}`);
  }
}

// ── Section 3: Architecture ───────────────────────────────────────────────────
function checkArchitecture() {
  // firestoreProvider must not be redeclared in feature files
  const duplicateProviders = grepLib("firestoreProvider = Provider<FirebaseFirestore>")
    .filter((p) => !p.replace(/\\/g, "/").includes("core/providers/firebase_providers.dart"));

  addCheck("arch", "firestoreProvider declared only once (canonical)",
    duplicateProviders.length === 0 ? "PASS" : "FAIL",
    duplicateProviders.length > 0 ? `duplicates: ${duplicateProviders.join(", ")}` : null);

  // stream_registry.dart exists
  addCheck("arch", "stream_registry.dart present",
    fileExists("lib/core/architecture/stream_registry.dart") ? "PASS" : "WARN",
    !fileExists("lib/core/architecture/stream_registry.dart") ?
      "create lib/core/architecture/stream_registry.dart" : null);

  // architecture test exists
  addCheck("arch", "stream_registry_test.dart present",
    fileExists("test/architecture/stream_registry_test.dart") ? "PASS" : "WARN");

  // FirebaseFirestore.instance in widgets/screens
  const rawInstanceUsage = grepLib("FirebaseFirestore.instance")
    .filter((p) =>
      (p.includes("screen") || p.includes("widget") || p.includes("providers/")) &&
      !p.includes("lib/dev/") &&
      !p.includes("core/providers/"),
    );

  addCheck("arch", "No raw FirebaseFirestore.instance in UI layer",
    rawInstanceUsage.length === 0 ? "PASS" : "WARN",
    rawInstanceUsage.length > 0 ?
      `${rawInstanceUsage.length} usages: ${rawInstanceUsage.slice(0, 3).join(", ")}` : null);
}

// ── Section 4: Rules ──────────────────────────────────────────────────────────
function checkRules() {
  const rulesPath = "firestore.rules";
  if (!fileExists(rulesPath)) {
    addCheck("rules", "firestore.rules present", "FAIL");
    return;
  }

  addCheck("rules", "firestore.rules present", "PASS");

  const required = [
    ["match /users/{userId}", "users collection rule"],
    ["match /conversations/{conversationId}", "conversations collection rule"],
    ["match /rooms/{roomId}", "rooms collection rule"],
    ["match /follows/{followId}", "follows collection rule"],
    ["function signedIn()", "signedIn() helper"],
  ];

  for (const [pattern, label] of required) {
    addCheck("rules", `Rules cover: ${label}`,
      fileContains(rulesPath, pattern) ? "PASS" : "FAIL",
      !fileContains(rulesPath, pattern) ? `Pattern missing: "${pattern}"` : null);
  }

  // Ensure no "allow read, write: if true;" (open collection)
  const openRules = [];
  const rulesContent = fs.readFileSync(path.join(WORKSPACE_ROOT, rulesPath), "utf8").split("\n");
  rulesContent.forEach((line, i) => {
    if (/allow\s+(read|write)[^:]*:\s*if\s+true\s*;/.test(line)) {
      openRules.push(`Line ${i + 1}: ${line.trim()}`);
    }
  });

  addCheck("rules", "No open allow:true rules",
    openRules.length === 0 ? "PASS" : "FAIL",
    openRules.length > 0 ? openRules.join("; ") : null);
}

// ── Section 5: Deploy gates ───────────────────────────────────────────────────
function checkDeployGates() {
  // deploy.ps1 includes validate-firestore-truth
  addCheck("gates", "deploy.ps1 runs Firestore validator",
    fileContains("deploy.ps1", "validate-firestore-truth") ? "PASS" : "FAIL",
    !fileContains("deploy.ps1", "validate-firestore-truth") ?
      "Inject validate-firestore-truth stage into deploy.ps1" : null);

  // firebase.json predeploy includes validate
  addCheck("gates", "firebase.json predeploy includes validate",
    fileContains("firebase.json", "run validate") ? "PASS" : "FAIL");

  // repair scripts exist
  const repairScripts = [
    "functions/scripts/repair-conversations.js",
    "functions/scripts/repair-messages.js",
    "functions/scripts/repair-rooms.js",
    "functions/scripts/repair-follows.js",
  ];
  for (const script of repairScripts) {
    addCheck("gates", `Repair script: ${path.basename(script)}`,
      fileExists(script) ? "PASS" : "FAIL");
  }

  // validate script exists
  addCheck("gates", "validate-firestore-truth.js present",
    fileExists("functions/scripts/validate-firestore-truth.js") ? "PASS" : "FAIL");

  // stress test harness exists
  addCheck("gates", "stress-test-harness.js present",
    fileExists("functions/scripts/stress-test-harness.js") ? "PASS" : "WARN",
    !fileExists("functions/scripts/stress-test-harness.js") ?
      "Recommended for pre-launch stress validation" : null);
}

// ── Section 6: Security ───────────────────────────────────────────────────────
function checkSecurity() {
  // storage.rules exists
  addCheck("security", "storage.rules present",
    fileExists("storage.rules") ? "PASS" : "WARN");

  // No hardcoded API keys or secrets in lib/
  const secretPatterns = [
    /AIza[0-9A-Za-z-_]{35}/, // Firebase API key
    /AAAA[A-Za-z0-9_-]{7}:/, // FCM server key
    /sk_live_/,               // Stripe live key
    /password\s*=\s*["'][^"']{6,}/i,
  ];

  let secretHits = 0;
  for (const pattern of secretPatterns) {
    // Exclude firebase_options.dart — standard generated Flutter Firebase config
    const hits = grepLib(pattern).filter((p) => !p.replace(/\\/g, "/").includes("lib/firebase_options.dart"));
    secretHits += hits.length;
    if (hits.length > 0) {
      addCheck("security", `No hardcoded secrets (${pattern.source.slice(0, 20)}…)`,
        "FAIL", `found in: ${hits.slice(0, 3).join(", ")}`);
    }
  }
  if (secretHits === 0) {
    addCheck("security", "No hardcoded API keys or secrets in lib/", "PASS");
  }

  // adultModeEnabled check exists in rules
  addCheck("security", "Rules enforce adultModeEnabled for adult rooms",
    fileContains("firestore.rules", "adultModeEnabled") ? "PASS" : "FAIL",
    !fileContains("firestore.rules", "adultModeEnabled") ?
      "Adult content access control must be enforced in firestore.rules" : null);

  // No eval / Function() in JS functions
  const evalHits = grepLib("eval(", {dir: FUNCTIONS_DIR, ext: ".js"})
    .filter((p) => !p.includes("node_modules") && !p.includes("eslintrc") && !p.replace(/\\/g, "/").includes("scripts/ship-checklist.js"));
  addCheck("security", "No eval() in Cloud Functions",
    evalHits.length === 0 ? "PASS" : "FAIL",
    evalHits.length > 0 ? evalHits.join(", ") : null);
}

// ── MAIN ─────────────────────────────────────────────────────────────────────
async function run() {
  const startedAt = new Date();
  if (!JSON_MODE) {
    console.log(`[ship-checklist] ${startedAt.toISOString()}`);
    console.log("─────────────────────────────────────────────────────────────");
  }

  if (!JSON_MODE) console.log("\n[1/6] Environment");
  await checkEnvironment();

  if (!JSON_MODE) console.log("\n[2/6] Data integrity");
  await checkDataIntegrity();

  if (!JSON_MODE) console.log("\n[3/6] Architecture");
  checkArchitecture();

  if (!JSON_MODE) console.log("\n[4/6] Firestore rules");
  checkRules();

  if (!JSON_MODE) console.log("\n[5/6] Deploy gates");
  checkDeployGates();

  if (!JSON_MODE) console.log("\n[6/6] Security");
  checkSecurity();

  const finishedAt = new Date();
  const passed = failCount === 0;

  const report = {
    schemaVersion: "1.0.0",
    startedAt: startedAt.toISOString(),
    finishedAt: finishedAt.toISOString(),
    durationMs: finishedAt - startedAt,
    passed,
    failCount,
    warnCount,
    totalChecks: checks.length,
    checks,
  };

  // Write JSON report
  const reportDir = path.join(WORKSPACE_ROOT, "tools", "reports");
  if (!fs.existsSync(reportDir)) fs.mkdirSync(reportDir, {recursive: true});
  const reportPath = path.join(reportDir, "ship_checklist.json");
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));

  if (JSON_MODE) {
    process.stdout.write(JSON.stringify(report, null, 2) + "\n");
  } else {
    console.log("\n─────────────────────────────────────────────────────────────");
    console.log(`[ship-checklist] RESULT: ${passed ? "✅ SHIP IT" : "❌ NOT READY"}`);
    console.log(`  checks: ${checks.length}   failures: ${failCount}   warnings: ${warnCount}`);
    console.log(`  report: ${reportPath}`);

    if (!passed) {
      console.log("\n── Failed checks ─────────────────────────────────────────");
      checks.filter((c) => c.status === "FAIL")
        .forEach((c) => console.error(`  ❌ [${c.category}] ${c.name}${c.detail ? `\n     ${c.detail}` : ""}`));
    }
  }

  process.exit(passed ? 0 : 1);
}

run().catch((err) => {
  console.error("[ship-checklist] fatal:", err);
  process.exit(2);
});
