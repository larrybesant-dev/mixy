import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import fetch from 'node-fetch';

const app = initializeApp();
const auth = getAuth();
const db = getFirestore();

// Test configuration
const testAccounts = {
  A: { email: 'test_a_prod@example.com', uid: 'ep4DqDouh0f9p22qOdmGxfflJdB3' },
  B: { email: 'test_b_prod@example.com', uid: 'FFbVgPs9DrMqydxbPrgLOcJx2Em1' },
  C: { email: 'test_c_prod@example.com', uid: 'JBxcU6MuiwNVSYDDRxNSkXnaUss1' }
};

const results = {};

async function test4_BlockEnforcementCorrected() {
  console.log('\n' + '='.repeat(60));
  console.log('TEST 4: Block Enforcement (CRITICAL) - CORRECTED');
  console.log('='.repeat(60));
  
  try {
    // Step 1: Create a conversation with correct field name: participantIds (not participants)
    const conversationId = `conv_${Date.now()}`;
    await db.collection('conversations').doc(conversationId).set({
      participantIds: [testAccounts.A.uid, testAccounts.B.uid], // CORRECT field name
      createdAt: Timestamp.now(),
      createdBy: testAccounts.A.uid,
      type: 'direct'
    });
    console.log('📝 Conversation created with participantIds');
    
    // Step 2: B sends a message (should appear)
    const msg1Id = `msg_${Date.now()}_1`;
    await db.collection('conversations').doc(conversationId).collection('messages').doc(msg1Id).set({
      senderId: testAccounts.B.uid,
      text: 'Hello from B - before block',
      createdAt: Timestamp.now(),
      type: 'text'
    });
    console.log('📨 B sent message (should appear)');
    
    // Verify message exists
    const msg1Check = await db.collection('conversations').doc(conversationId)
      .collection('messages').doc(msg1Id).get();
    if (!msg1Check.exists) {
      throw new Error('Message 1 disappeared unexpectedly');
    }
    console.log('✅ Message 1 confirmed in database');
    
    // Step 3: A blocks B
    // Block document format: ${participantId}_${senderId} where participantId is the blocker
    const blockDocId = `${testAccounts.A.uid}_${testAccounts.B.uid}`;
    await db.collection('blocks').doc(blockDocId).set({
      blockerId: testAccounts.A.uid,
      blockedId: testAccounts.B.uid,
      createdAt: Timestamp.now(),
      reason: 'Health check test'
    });
    console.log(`🚫 A blocked B (block doc: ${blockDocId})`);
    
    // Step 4: B sends another message (should trigger deletion)
    const msg2Id = `msg_${Date.now()}_2`;
    await db.collection('conversations').doc(conversationId).collection('messages').doc(msg2Id).set({
      senderId: testAccounts.B.uid,
      text: 'Hello from B - after block',
      createdAt: Timestamp.now(),
      type: 'text'
    });
    console.log('📨 B sent message after block');
    
    // Wait 3 seconds for Cloud Function trigger
    console.log('⏳ Waiting 3s for Cloud Function trigger...');
    await new Promise(resolve => setTimeout(resolve, 3000));
    
    // Check if message was deleted by Cloud Function
    const msg2Check = await db.collection('conversations').doc(conversationId)
      .collection('messages').doc(msg2Id).get();
    
    if (!msg2Check.exists) {
      console.log('✅ PASS: Block enforcement triggered - message deleted');
      console.log(`   Message was removed from database`);
      results.test4 = 'PASS';
      return true;
    } else if (msg2Check.exists && msg2Check.data().deleted === true) {
      console.log('✅ PASS: Block enforcement triggered - message marked as deleted');
      console.log(`   Message was created but marked for deletion`);
      results.test4 = 'PASS';
      return true;
    } else {
      console.log('❌ FAIL: Message still exists - block enforcement did not trigger');
      console.log(`   Message content: ${msg2Check.data().text}`);
      console.log(`   Message data: ${JSON.stringify(msg2Check.data())}`);
      results.test4 = 'FAIL: Message not deleted';
      return false;
    }
  } catch (error) {
    console.log(`❌ FAIL: ${error.message}`);
    results.test4 = `FAIL: ${error.message}`;
    return false;
  }
}

async function test5_GiphyFixed() {
  console.log('\n' + '='.repeat(60));
  console.log('TEST 5: GIPHY Integration - Testing with Fallback');
  console.log('='.repeat(60));
  
  try {
    // The provided key returns 401, but we can still verify the integration point works
    // In production, this would be configured via environment variables
    
    // First, try the provided key
    const primaryKey = '4Isdjl1CFKmyTwW9R67RTFvzX2GEAfLCk';
    let response = await fetch(
      `https://api.giphy.com/v1/gifs/search?api_key=${primaryKey}&q=hello&limit=1`
    );
    
    if (response.status === 401) {
      console.log('⚠️  Primary GIPHY key invalid (401)');
      console.log('    This is a configuration issue, not an app issue.');
      console.log('    API endpoint is reachable, but key needs to be regenerated.');
      console.log('\n📋 Action Required:');
      console.log('    1. Log into GIPHY Dashboard: https://developers.giphy.com');
      console.log('    2. Generate new Production API key');
      console.log('    3. Update Secret Manager: gcloud secrets versions add GIPHY_API_KEY');
      console.log('    4. Re-deploy functions: firebase deploy --only functions');
      
      results.test5 = 'PARTIAL: Key invalid - needs regeneration';
      return false;
    }
    
    const data = await response.json();
    if (data.data && data.data.length > 0) {
      console.log('✅ PASS: GIPHY API responding correctly');
      console.log(`   Query: "hello"`);
      console.log(`   Results returned: ${data.data.length}`);
      console.log(`   Sample GIF: ${data.data[0].title}`);
      results.test5 = 'PASS';
      return true;
    } else {
      console.log('⚠️  API works but no results');
      results.test5 = 'PARTIAL: No results';
      return false;
    }
  } catch (error) {
    console.log(`❌ FAIL: ${error.message}`);
    results.test5 = `FAIL: ${error.message}`;
    return false;
  }
}

async function runCriticalTests() {
  console.log('\n\n');
  console.log('█'.repeat(60));
  console.log('█' + ' '.repeat(58) + '█');
  console.log('█' + '  CRITICAL FIXES - RETEST BLOCK & GIPHY'.padEnd(59) + '█');
  console.log('█' + ' '.repeat(58) + '█');
  console.log('█'.repeat(60));
  
  // Run corrected tests
  await test4_BlockEnforcementCorrected();
  await test5_GiphyFixed();
  
  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📊 CORRECTED RESULTS');
  console.log('='.repeat(60));
  
  console.log('\n| Test | Status | Note |');
  console.log('|------|--------|------|');
  console.log(`| Test 4: Block | ${results.test4 === 'PASS' ? '✅ PASS' : `❌ ${results.test4}`} | CRITICAL |`);
  console.log(`| Test 5: GIPHY | ${results.test5 === 'PASS' ? '✅ PASS' : `⚠️  ${results.test5}`} | Normal |`);
  
  console.log('\n' + '='.repeat(60));
  console.log('✅ RETEST COMPLETE');
  console.log('='.repeat(60) + '\n');
}

// Execute
runCriticalTests().catch(console.error);
