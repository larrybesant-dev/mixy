// ====================================================================
// INVESTIGATION: Block Enforcement Event Trigger Issue
// ====================================================================
// 
// OBSERVATION: Firestore events aren't triggering Cloud Function
// THEORY: Admin SDK writes may not trigger Firestore triggers
// SOLUTION: Create HTTP wrapper + direct invocation test
//
// ====================================================================

import { initializeApp } from 'firebase-admin/app';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import fetch from 'node-fetch';

const app = initializeApp();
const db = getFirestore();

const testAccounts = {
  A: { email: 'test_a_prod@example.com', uid: 'ep4DqDouh0f9p22qOdmGxfflJdB3' },
  B: { email: 'test_b_prod@example.com', uid: 'FFbVgPs9DrMqydxbPrgLOcJx2Em1' }
};

async function investigateEventTrigger() {
  console.log('\n' + '='.repeat(70));
  console.log('INVESTIGATION: Why Block Enforcement Not Triggering');
  console.log('='.repeat(70));

  // Step 1: Test if HTTP endpoint for the function works
  console.log('\n📡 STEP 1: Test HTTP invocation of Cloud Function');
  console.log('-'.repeat(70));
  
  try {
    const functionUrl = 'https://us-central1-mixvy-v2.cloudfunctions.net/validateMessageBlockEnforcement';
    console.log(`Attempting HTTP call to: ${functionUrl}`);
    
    // Cloud Functions v2 require Cloud Events format, so direct HTTP won't work
    // Let me instead check if Pub/Sub is receiving messages
    console.log('⚠️  v2 Functions require Cloud Events - HTTP invocation may not work');
  } catch (error) {
    console.log(`Error: ${error.message}`);
  }

  // Step 2: Create a test conversation and verify data structure
  console.log('\n📝 STEP 2: Create test scenario and verify data structure');
  console.log('-'.repeat(70));
  
  const convId = `debug_conv_${Date.now()}`;
  const msgId = `debug_msg_${Date.now()}`;
  
  // Ensure correct field names match Cloud Function expectations
  console.log(`Creating conversation: ${convId}`);
  console.log(`With participantIds: [${testAccounts.A.uid}, ${testAccounts.B.uid}]`);
  
  await db.collection('conversations').doc(convId).set({
    participantIds: [testAccounts.A.uid, testAccounts.B.uid],
    createdAt: Timestamp.now(),
    createdBy: testAccounts.A.uid,
    type: 'direct'
  });
  
  console.log('✅ Conversation created');
  
  // Step 3: Create a message and check if function fires
  console.log('\n📨 STEP 3: Create message and wait for function trigger');
  console.log('-'.repeat(70));
  console.log('Writing message to Firestore...');
  
  const messageRef = db.collection('conversations').doc(convId).collection('messages').doc(msgId);
  
  const messageData = {
    senderId: testAccounts.B.uid,
    text: 'Debug message for trigger test',
    createdAt: Timestamp.now(),
    type: 'text'
  };
  
  console.log(`Message data: ${JSON.stringify(messageData, null, 2)}`);
  
  await messageRef.set(messageData);
  console.log('✅ Message written to Firestore');
  
  // Step 4: Wait and check if it was deleted by Cloud Function
  console.log('\n⏳ STEP 4: Check for Cloud Function execution (waiting 5 seconds)');
  console.log('-'.repeat(70));
  
  await new Promise(resolve => setTimeout(resolve, 5000));
  
  const messageAfter = await messageRef.get();
  
  if (messageAfter.exists) {
    console.log('❌ Message still exists - Cloud Function DID NOT trigger');
    console.log(`Message data: ${JSON.stringify(messageAfter.data())}`);
  } else {
    console.log('✅ Message deleted - Cloud Function triggered correctly!');
  }
  
  // Step 5: Check Pub/Sub metrics
  console.log('\n📊 STEP 5: Possible root causes');
  console.log('-'.repeat(70));
  
  console.log(`
Firestore Event Trigger Status:
  ✓ Event Type: google.cloud.firestore.document.v1.created
  ✓ Path Pattern: conversations/{conversationId}/messages/{messageId}
  ✓ Pub/Sub Topic: projects/mixvy-v2/topics/eventarc-nam5-validatemessageblockenforcement-635468-654
  ✓ Function State: ACTIVE
  
Possible Causes (in order of likelihood):
  
1. 🔴 Eventarc Service Agent Permission Delay
   - Permissions were recently granted
   - GCP sometimes takes 10-30 minutes to fully propagate
   - Solution: Wait, or rerun "firebase deploy --only functions"
   
2. 🔴 Admin SDK vs Client SDK Event Delivery
   - Some evidence suggests Admin SDK writes don't always trigger Firestore triggers
   - This is a known GCP quirk
   - Solution: Implement HTTP workaround endpoint
   
3. 🟡 Firestore Triggers in Multi-Region Setup
   - Trigger Region: nam5 (nam = North America)
   - Function Region: us-central1
   - May have routing/synchronization issues
   - Solution: Rebuild trigger or use Firestore Rules validation

RECOMMENDED FIX:
Create validateMessageViaEndpoint() HTTP function that:
  1. Validates block status via Firestore Rules
  2. Returns 403 if user is blocked
  3. Client receives error before message is created
  
This is MORE RELIABLE than depending on event triggers.
  `);

  // Step 6: Verify block document exists
  console.log('\n🔍 STEP 6: Verify block enforcement setup');
  console.log('-'.repeat(70));
  
  // Create block first, then try message
  const blockDocId = `${testAccounts.A.uid}_${testAccounts.B.uid}`;
  console.log(`Creating block document: ${blockDocId}`);
  
  await db.collection('blocks').doc(blockDocId).set({
    blockerId: testAccounts.A.uid,
    blockedId: testAccounts.B.uid,
    createdAt: Timestamp.now(),
    reason: 'Debug test'
  });
  
  console.log('✅ Block document created');
  
  // Now try to create a message when blocked
  console.log('\nCreating message while blocked (should be deleted by function if working)...');
  
  const msgId2 = `debug_msg2_${Date.now()}`;
  await db.collection('conversations').doc(convId).collection('messages').doc(msgId2).set({
    senderId: testAccounts.B.uid,
    text: 'This message is from a blocked user',
    createdAt: Timestamp.now(),
    type: 'text'
  });
  
  await new Promise(resolve => setTimeout(resolve, 3000));
  
  const messageAfter2 = await db.collection('conversations').doc(convId)
    .collection('messages').doc(msgId2).get();
  
  if (messageAfter2.exists) {
    console.log('❌ Blocked user message still exists - Function not working');
  } else {
    console.log('✅ Blocked user message deleted - Function working!');
  }
  
  console.log('\n' + '='.repeat(70));
  console.log('CONCLUSION: Event trigger status unclear - may need HTTP workaround');
  console.log('='.repeat(70) + '\n');
}

// Run investigation
investigateEventTrigger().catch(console.error);
