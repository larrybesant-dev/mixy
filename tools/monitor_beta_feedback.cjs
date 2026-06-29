#!/usr/bin/env node
/**
 * Real-Time Feedback Monitor
 * 
 * Watches Firestore for beta_feedback submissions from tester
 * and logs them in real-time with latency correlation analysis.
 */

const admin = require("firebase-admin");

// Uses GOOGLE_APPLICATION_CREDENTIALS env var or GCP environment
admin.initializeApp();

const db = admin.firestore();

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

const TARGET_UID = "m6UqL501Z8ZJ0mvEHxvz7oX2wkm2";
const CAMPAIGN_ID = "network-health-phase-5";
const MONITOR_DURATION_MS = 48 * 60 * 60 * 1000; // 48 hours

let feedbackCount = 0;
let startTime = Date.now();

// ─────────────────────────────────────────────────────────────────────────────
// Formatting Helpers
// ─────────────────────────────────────────────────────────────────────────────

function formatTimestamp(ts) {
  if (!ts) return "N/A";
  const date = ts.toDate ? ts.toDate() : new Date(ts);
  return date.toISOString();
}

function formatDuration(ms) {
  const hours = Math.floor(ms / 3600000);
  const minutes = Math.floor((ms % 3600000) / 60000);
  const seconds = Math.floor((ms % 60000) / 1000);
  return `${hours}h ${minutes}m ${seconds}s`;
}

// ─────────────────────────────────────────────────────────────────────────────
// Feedback Processing
// ─────────────────────────────────────────────────────────────────────────────

function parseFeedback(doc) {
  const data = doc.data() || {};
  
  return {
    id: doc.id,
    timestamp: data.timestamp,
    submittedAt: formatTimestamp(data.timestamp),
    checklist: data.checklist || {},
    fullReport: data.fullReport || "",
    overallFeeling: data.checklist?.overallFeeling || "unknown",
    indicatorAccuracy: data.checklist?.indicatorAccuracy || "unknown",
  };
}

function formatFeedbackDisplay(feedback) {
  console.log("\n" + "═".repeat(70));
  console.log("🎉 FEEDBACK RECEIVED!");
  console.log("═".repeat(70));
  console.log(`ID: ${feedback.id}`);
  console.log(`Submitted: ${feedback.submittedAt}`);
  console.log(`Overall Feeling: ${feedback.overallFeeling}`);
  console.log(`Indicator Accuracy: ${feedback.indicatorAccuracy}`);
  if (feedback.fullReport) {
    console.log(`\nReport:\n${feedback.fullReport}`);
  }
  console.log("═".repeat(70));
}

async function queryLatencyLogs(testerUid, feedbackTimestamp) {
  console.log("\n🔍 Querying latency logs near feedback timestamp...");
  
  try {
    // In a real system, you'd query your logging backend or Firestore
    // For now, we'll provide a template for where to look
    
    const feedbackTime = feedbackTimestamp.toDate ? feedbackTimestamp.toDate() : new Date(feedbackTimestamp);
    const window = 5 * 60 * 1000; // 5 minutes before/after feedback
    const before = new Date(feedbackTime.getTime() - window);
    const after = new Date(feedbackTime.getTime() + window);
    
    console.log(`   Time Window: ${before.toISOString()} → ${after.toISOString()}`);
    console.log(`   Expected logs: [WebRtcLatency] logs with tag: golden-${CAMPAIGN_ID}-*`);
    console.log(`   Query: Check console logs or APM dashboard for this UID during this window`);
    
    return {
      windowStart: before.toISOString(),
      windowEnd: after.toISOString(),
      logsFound: 0,
      details: "Manual review needed - check WebRTC dashboard"
    };
  } catch (error) {
    console.error(`   ❌ Error: ${error.message}`);
    return null;
  }
}

function correlateWithExperience(feedback) {
  console.log("\n💡 Correlation Analysis:");
  
  const feeling = feedback.overallFeeling?.toLowerCase() || "";
  const accuracy = feedback.indicatorAccuracy?.toLowerCase() || "";
  
  let correlation = "❓ UNKNOWN";
  let confidence = 0;
  
  if (accuracy.includes("match") || accuracy.includes("perfect") || accuracy.includes("accurate")) {
    correlation = "✅ MATCH";
    confidence = 95;
  } else if (accuracy.includes("mostly") || accuracy.includes("approximate")) {
    correlation = "⚠️ PARTIAL";
    confidence = 70;
  } else if (accuracy.includes("mismatch") || accuracy.includes("don't match") || accuracy.includes("didn't match")) {
    correlation = "❌ MISMATCH";
    confidence = 10;
  }
  
  console.log(`   Status: ${correlation}`);
  console.log(`   Confidence: ${confidence}%`);
  console.log(`   User Feeling: ${feeling}`);
  console.log(`   Indicator Correlation: ${accuracy}`);
  
  return { correlation, confidence, feeling, accuracy };
}

// ─────────────────────────────────────────────────────────────────────────────
// Firestore Listener
// ─────────────────────────────────────────────────────────────────────────────

async function setupRealtimeListener() {
  console.log("🚀 Real-Time Feedback Monitor Started");
  console.log(`   Watching: users/${TARGET_UID}/beta_feedback`);
  console.log(`   Campaign: ${CAMPAIGN_ID}`);
  console.log(`   Duration: 48 hours (until ${new Date(startTime + MONITOR_DURATION_MS).toISOString()})`);
  console.log(`   Golden User: golden-${CAMPAIGN_ID}-2026-06-29\n`);

  const feedbackPath = db.collection("users").doc(TARGET_UID).collection("beta_feedback");

  // Listener for new feedback documents
  const unsubscribe = feedbackPath
    .orderBy("timestamp", "desc")
    .limit(10)
    .onSnapshot(
      async (snapshot) => {
        snapshot.docChanges().forEach(async (change) => {
          if (change.type === "added") {
            feedbackCount++;
            
            console.log(`\n[${new Date().toISOString()}] New feedback detected!`);
            
            const feedback = parseFeedback(change.doc);
            formatFeedbackDisplay(feedback);
            
            // Query latency logs
            const latencyAnalysis = await queryLatencyLogs(TARGET_UID, feedback.timestamp);
            if (latencyAnalysis) {
              console.log("\n📊 Latency Analysis Window:");
              console.log(`   Start: ${latencyAnalysis.windowStart}`);
              console.log(`   End: ${latencyAnalysis.windowEnd}`);
              console.log(`   Status: ${latencyAnalysis.details}`);
            }
            
            // Correlation analysis
            const correlation = correlateWithExperience(feedback);
            
            // Log to file for audit trail
            console.log("\n💾 Saving to audit log...");
            await saveAuditLog(feedback, correlation, latencyAnalysis);
            
            // Update calibration log memory
            console.log("📝 Update needed: /memories/session/beta-feedback-calibration-log.md");
            console.log(`   Entry: Feedback #${feedbackCount} from ${TARGET_UID}`);
            console.log(`   Correlation: ${correlation.correlation}`);
            console.log(`   Confidence: ${correlation.confidence}%`);
          }
        });
      },
      (error) => {
        console.error(`\n❌ Listener error: ${error.message}`);
        process.exit(1);
      }
    );

  // Graceful shutdown handler
  process.on("SIGINT", () => {
    console.log("\n\n🛑 Monitor shutting down...");
    unsubscribe();
    
    const elapsed = Date.now() - startTime;
    console.log(`\n📊 Final Statistics:`);
    console.log(`   Total Feedback Received: ${feedbackCount}`);
    console.log(`   Monitor Duration: ${formatDuration(elapsed)}`);
    console.log(`   Status: Monitor detached successfully`);
    
    process.exit(0);
  });

  return unsubscribe;
}

async function saveAuditLog(feedback, correlation, latencyAnalysis) {
  try {
    await db.collection("beta_campaigns").doc(CAMPAIGN_ID).collection("feedback_audit").add({
      testerUid: TARGET_UID,
      feedbackId: feedback.id,
      submittedAt: feedback.timestamp,
      receivedAt: admin.firestore.FieldValue.serverTimestamp(),
      overallFeeling: feedback.overallFeeling,
      indicatorAccuracy: feedback.indicatorAccuracy,
      correlationStatus: correlation.correlation,
      correlationConfidence: correlation.confidence,
      latencyWindowStart: latencyAnalysis?.windowStart,
      latencyWindowEnd: latencyAnalysis?.windowEnd,
      fullReport: feedback.fullReport,
    });
    console.log(`   ✅ Audit log saved`);
  } catch (error) {
    console.error(`   ⚠️ Audit save failed: ${error.message}`);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main
// ─────────────────────────────────────────────────────────────────────────────

async function main() {
  console.log("═".repeat(70));
  console.log("📡 PHASE 5: Real-Time Feedback Monitoring");
  console.log("═".repeat(70));

  try {
    await setupRealtimeListener();
    
    console.log("\n✅ Listener attached. Waiting for feedback...");
    console.log("   Press Ctrl+C to stop monitoring\n");
    
    // Keep process alive
    await new Promise(() => {});
  } catch (error) {
    console.error("Fatal error:", error);
    process.exit(1);
  }
}

main();
