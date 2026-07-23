#!/usr/bin/env node
/**
 * Phase 5: Omnichannel Outreach Dispatch + Golden User Tagging
 * 
 * Sends Network Health Widget outreach to beta testers via:
 * 1. In-App Notification (FCM push)
 * 2. Email notification
 * 3. Tags user for isolated telemetry tracking (Golden User)
 */

const admin = require("firebase-admin");

// Uses GOOGLE_APPLICATION_CREDENTIALS env var or GCP environment
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

// ─────────────────────────────────────────────────────────────────────────────
// Configuration
// ─────────────────────────────────────────────────────────────────────────────

const TARGET_UID = "m6UqL501Z8ZJ0mvEHxvz7oX2wkm2";
const CAMPAIGN_ID = "network-health-phase-5";
const OUTREACH_TIMESTAMP = new Date().toISOString();

const IN_APP_MESSAGE = {
  title: "🎯 Network Health Widget Live!",
  body: "We deployed real-time network indicators (🟢🟡🔴) in live rooms. Watch them change as your connection shifts. Report what you see in Settings → Beta Feedback!",
  type: "beta_feature_announcement",
};

const EMAIL_SUBJECT = "🎯 MIXVY Beta: Network Health Indicators Live";
const EMAIL_BODY = `Hi there! 👋

We just deployed Network Health indicators (🟢🟡🔴) to MIXVY live rooms to help you monitor connection quality in real-time.

🟢 **Green** = Excellent connection (< 1 sec latency)
🟡 **Yellow** = Connecting... (1-2 sec latency)
🔴 **Red** = Poor connection (> 2 sec latency)

**How to test:**
1. Join a live room
2. Look for the colored dot at the top-right of the video feed
3. Watch it change as your connection quality shifts
4. Report your experience in Settings → Beta Feedback

Your feedback helps us build a better MIXVY. Thanks for testing! 🚀

— The MIXVY Team`;

// ─────────────────────────────────────────────────────────────────────────────
// Dispatch Functions
// ─────────────────────────────────────────────────────────────────────────────

async function sendInAppNotification(uid) {
  console.log(`\n📲 Sending In-App Notification to ${uid}...`);

  try {
    // Create notification document that triggers FCM push via Cloud Function
    const notifRef = await db
      .collection("users")
      .doc(uid)
      .collection("notifications")
      .add({
        userId: uid,
        type: IN_APP_MESSAGE.type,
        title: IN_APP_MESSAGE.title,
        content: IN_APP_MESSAGE.body,
        campaignId: CAMPAIGN_ID,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        read: false,
        readAt: null,
      });

    console.log(`   ✅ Notification created: ${notifRef.id}`);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed: ${error.message}`);
    return false;
  }
}

async function sendEmailNotification(uid, userEmail) {
  console.log(`\n📧 Sending Email to ${userEmail}...`);

  try {
    // Store email task for Firebase Extensions Email extension or backend service
    await db
      .collection("mail")
      .add({
        to: [userEmail],
        message: {
          subject: EMAIL_SUBJECT,
          html: `<pre>${EMAIL_BODY}</pre>`,
          text: EMAIL_BODY,
        },
        campaignId: CAMPAIGN_ID,
        userId: uid,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

    console.log(`   ✅ Email queued for ${userEmail}`);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed: ${error.message}`);
    return false;
  }
}

async function tagGoldenUser(uid) {
  console.log(`\n🏆 Tagging Golden User for Telemetry Isolation...`);

  try {
    await db.collection("users").doc(uid).set(
      {
        goldenUserTag: {
          enabled: true,
          campaign: CAMPAIGN_ID,
          taggedAt: new Date().toISOString(),
          isolatedMetrics: true,
          telemetryLabel: `golden-${CAMPAIGN_ID}-${new Date().toISOString().split("T")[0]}`,
        },
      },
      { merge: true }
    );

    console.log(`   ✅ Golden User tag applied`);
    console.log(`      Telemetry Label: golden-${CAMPAIGN_ID}-*`);
    console.log(`      Impact: All [WebRtcLatency] logs will include this tag`);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed: ${error.message}`);
    return false;
  }
}

async function createCampaignAuditLog(uid, results) {
  console.log(`\n📋 Creating Campaign Audit Log...`);

  try {
    await db.collection("beta_campaigns").doc(CAMPAIGN_ID).set(
      {
        name: "Network Health Widget Phase 5 Outreach",
        startDate: OUTREACH_TIMESTAMP,
        targetAudience: "active_listeners",
        testers: {
          [uid]: {
            inAppSent: results.inApp,
            emailSent: results.email,
            goldenUserTagged: results.goldenUser,
            sentAt: OUTREACH_TIMESTAMP,
            sentBy: "promote_active_listeners_dispatch",
          },
        },
        metrics: {
          targetCount: 1,
          successCount: Object.values(results).filter((v) => v).length,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        },
      },
      { merge: true }
    );

    console.log(`   ✅ Audit log created`);
    return true;
  } catch (error) {
    console.error(`   ❌ Failed: ${error.message}`);
    return false;
  }
}

async function getTesterEmail(uid) {
  console.log(`\n🔍 Looking up tester email for ${uid}...`);

  try {
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      console.log(`   ⚠️  User document not found`);
      return null;
    }

    const userData = userDoc.data();
    const email = userData.email || userData.emailAddress;

    if (email) {
      console.log(`   ✅ Found: ${email}`);
      return email;
    }

    console.log(`   ⚠️  No email field found in user document`);
    return null;
  } catch (error) {
    console.error(`   ❌ Lookup failed: ${error.message}`);
    return null;
  }
}

async function main() {
  console.log("═══════════════════════════════════════════════════════════════");
  console.log("🚀 PHASE 5: Omnichannel Outreach + Golden User Telemetry Tagging");
  console.log("═══════════════════════════════════════════════════════════════");
  console.log(`Target UID: ${TARGET_UID}`);
  console.log(`Campaign ID: ${CAMPAIGN_ID}`);
  console.log(`Timestamp: ${OUTREACH_TIMESTAMP}\n`);

  try {
    // Step 1: Retrieve tester email
    const userEmail = await getTesterEmail(TARGET_UID);

    // Step 2: Send In-App Notification
    const inAppSuccess = await sendInAppNotification(TARGET_UID);

    // Step 3: Send Email (if email found)
    let emailSuccess = false;
    if (userEmail) {
      emailSuccess = await sendEmailNotification(TARGET_UID, userEmail);
    }

    // Step 4: Tag as Golden User
    const goldenUserSuccess = await tagGoldenUser(TARGET_UID);

    // Step 5: Create Audit Log
    const auditSuccess = await createCampaignAuditLog(TARGET_UID, {
      inApp: inAppSuccess,
      email: emailSuccess,
      goldenUser: goldenUserSuccess,
    });

    // Summary
    console.log("\n" + "═".repeat(60));
    console.log("📊 OUTREACH DISPATCH SUMMARY");
    console.log("═".repeat(60));
    console.log(`✅ In-App Notification: ${inAppSuccess ? "SENT" : "FAILED"}`);
    console.log(`✅ Email Notification:  ${emailSuccess ? "SENT" : "FAILED"}`);
    console.log(`✅ Golden User Tag:     ${goldenUserSuccess ? "APPLIED" : "FAILED"}`);
    console.log(`✅ Audit Log:           ${auditSuccess ? "CREATED" : "FAILED"}`);

    const successCount = [inAppSuccess, emailSuccess, goldenUserSuccess]
      .filter((v) => v).length;
    console.log(`\n📈 Success Rate: ${successCount}/3`);

    console.log("\n💡 Next Steps:");
    console.log("   1. Monitor Firestore > users/{uid}/beta_feedback for responses");
    console.log("   2. Check [WebRtcLatency] logs for golden-${CAMPAIGN_ID}-* tags");
    console.log("   3. Correlate feedback with latency metrics within 48 hours");
    console.log("   4. Update /memories/session/beta-feedback-calibration-log.md");

    console.log("\n🎯 Golden User Telemetry Tracking:");
    console.log(`   Filter logs by: goldenUserTag.telemetryLabel`);
    console.log(`   Expected format: golden-${CAMPAIGN_ID}-2026-06-29`);
    console.log("   This isolates their WebRTC metrics from other noise");

  } catch (error) {
    console.error("\n❌ Fatal error:", error);
    process.exit(1);
  }

  process.exit(0);
}

main();
