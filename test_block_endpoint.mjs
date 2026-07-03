#!/usr/bin/env node

import admin from "firebase-admin";
import { getAuth } from "firebase-admin/auth";
import { initializeApp } from "firebase-admin/app";

// Initialize Firebase Admin
const serviceAccountPath = "./functions/mixvy-v2-firebase-adminsdk-7uh8n-987d0cbfb2.json";
const serviceAccount = JSON.parse(
  (await import("fs")).readFileSync(serviceAccountPath, "utf8")
);

initializeApp({
  credential: admin.credential.cert(serviceAccount),
  projectId: "mixvy-v2",
});

const firestore = admin.firestore();

console.log("🧪 Testing Block Enforcement via HTTP Endpoint\n");

async function testBlockEnforcement() {
  try {
    // Get test accounts
    console.log("📋 Retrieving test accounts...\n");
    
    const testAccounts = {
      blocker: { email: "test_a_prod@example.com", name: "Account A (Blocker)" },
      blocked: { email: "test_b_prod@example.com", name: "Account B (Blocked)" },
    };

    // Create custom tokens for test accounts
    const blockerToken = await getAuth().createCustomToken("ep4DqDouh0f9p22qOdmGxfflJdB3");
    const blockedToken = await getAuth().createCustomToken("FFbVgPs9DrMqydxbPrgLOcJx2Em1");

    console.log("✅ Custom tokens created");
    console.log(`  - Blocker UID: ep4DqDouh0f9p22qOdmGxfflJdB3`);
    console.log(`  - Blocked UID: FFbVgPs9DrMqydxbPrgLOcJx2Em1\n`);

    // Get the Cloud Functions HTTP endpoint URL
    const functionUrl = "https://us-central1-mixvy-v2.cloudfunctions.net/checkBlockStatus";
    console.log(`🌐 Testing endpoint: ${functionUrl}\n`);

    // Test 1: Create a test conversation
    console.log("📝 Step 1: Creating test conversation...");
    const conversationRef = await firestore.collection("conversations").add({
      participantIds: ["ep4DqDouh0f9p22qOdmGxfflJdB3", "FFbVgPs9DrMqydxbPrgLOcJx2Em1"],
      createdAt: new Date(),
      createdBy: "ep4DqDouh0f9p22qOdmGxfflJdB3",
      lastMessageAt: new Date(),
    });
    const conversationId = conversationRef.id;
    console.log(`✅ Conversation created: ${conversationId}\n`);

    // Test 2: Blocker creates a block document against Blocked user
    console.log("🚫 Step 2: Creating block (Blocker → Blocked)...");
    await firestore
      .collection("blocks")
      .doc("ep4DqDouh0f9p22qOdmGxfflJdB3_FFbVgPs9DrMqydxbPrgLOcJx2Em1")
      .set({
        blockerId: "ep4DqDouh0f9p22qOdmGxfflJdB3",
        blockedId: "FFbVgPs9DrMqydxbPrgLOcJx2Em1",
        createdAt: new Date(),
      });
    console.log(`✅ Block document created\n`);

    // Test 3: Blocked user tries to send message (should fail)
    console.log("❌ Step 3: Blocked user attempts to send message...");
    console.log(`   Sending request as: FFbVgPs9DrMqydxbPrgLOcJx2Em1`);
    
    const blockedResponse = await fetch(functionUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${blockedToken}`,
      },
      body: JSON.stringify({
        data: {
          conversationId: conversationId,
        },
      }),
    });

    const blockedResult = await blockedResponse.json();
    console.log(`   Response Status: ${blockedResponse.status}`);
    console.log(`   Response Body:`, JSON.stringify(blockedResult, null, 2));

    if (blockedResult.result && blockedResult.result.canSend === false) {
      console.log(`   ✅ PASS: Block prevented message from blocked user\n`);
    } else {
      console.log(`   ❌ FAIL: Block did not prevent message\n`);
    }

    // Test 4: Blocker can send message to blocked user (one-way enforcement)
    console.log("✅ Step 4: Blocker sends message to blocked user...");
    console.log(`   Sending request as: ep4DqDouh0f9p22qOdmGxfflJdB3`);
    
    const blockerResponse = await fetch(functionUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${blockerToken}`,
      },
      body: JSON.stringify({
        data: {
          conversationId: conversationId,
        },
      }),
    });

    const blockerResult = await blockerResponse.json();
    console.log(`   Response Status: ${blockerResponse.status}`);
    console.log(`   Response Body:`, JSON.stringify(blockerResult, null, 2));

    if (blockerResult.result && blockerResult.result.canSend === true) {
      console.log(`   ✅ PASS: Blocker can send message\n`);
    } else {
      console.log(`   ❌ FAIL: Blocker cannot send message\n`);
    }

    // Test 5: Create second block in opposite direction
    console.log("🚫 Step 5: Creating reverse block (Blocked → Blocker)...");
    await firestore
      .collection("blocks")
      .doc("FFbVgPs9DrMqydxbPrgLOcJx2Em1_ep4DqDouh0f9p22qOdmGxfflJdB3")
      .set({
        blockerId: "FFbVgPs9DrMqydxbPrgLOcJx2Em1",
        blockedId: "ep4DqDouh0f9p22qOdmGxfflJdB3",
        createdAt: new Date(),
      });
    console.log(`✅ Reverse block document created\n`);

    // Test 6: Now blocker cannot send (bidirectional enforcement)
    console.log("❌ Step 6: Blocker attempts to send message (reverse block active)...");
    console.log(`   Sending request as: ep4DqDouh0f9p22qOdmGxfflJdB3`);
    
    const blockerResponse2 = await fetch(functionUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${blockerToken}`,
      },
      body: JSON.stringify({
        data: {
          conversationId: conversationId,
        },
      }),
    });

    const blockerResult2 = await blockerResponse2.json();
    console.log(`   Response Status: ${blockerResponse2.status}`);
    console.log(`   Response Body:`, JSON.stringify(blockerResult2, null, 2));

    if (blockerResult2.result && blockerResult2.result.canSend === false) {
      console.log(`   ✅ PASS: Reverse block prevented message from blocker\n`);
    } else {
      console.log(`   ❌ FAIL: Reverse block did not prevent message\n`);
    }

    console.log("✨ Block enforcement testing complete!");
  } catch (error) {
    console.error("❌ Error during testing:", error);
    process.exit(1);
  }
}

testBlockEnforcement();
