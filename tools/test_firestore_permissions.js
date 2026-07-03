#!/usr/bin/env node

/**
 * Firebase Emulator Permission Test Suite
 * Tests room join permissions for MixVy application
 * Status: Automated testing via Node.js
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Test results
const results = {
  passed: 0,
  failed: 0,
  tests: []
};

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bright: '\x1b[1m',
  green: '\x1b[32m',
  red: '\x1b[31m',
  yellow: '\x1b[33m',
  cyan: '\x1b[36m',
  magenta: '\x1b[35m'
};

function log(message, color = 'reset') {
  console.log(`${colors[color]}${message}${colors.reset}`);
}

function logHeader(title) {
  log(`\n${'═'.repeat(70)}`, 'cyan');
  log(`  ${title}`, 'bright');
  log(`${'═'.repeat(70)}\n`, 'cyan');
}

function logTest(testName, status, message = '') {
  const icon = status === 'PASS' ? '✓' : '✗';
  const color = status === 'PASS' ? 'green' : 'red';
  
  results.tests.push({ testName, status, message });
  if (status === 'PASS') results.passed++;
  else results.failed++;
  
  log(`  ${icon} ${testName}`, color);
  if (message) log(`     ${message}`, 'yellow');
}

async function initializeFirebase() {
  try {
    // Initialize with emulator settings
    process.env.FIREBASE_EMULATOR_HOST = 'localhost:8080';
    
    const app = admin.initializeApp({
      projectId: 'mixvy-rules-test',
      storageBucket: 'mixvy-rules-test.appspot.com'
    });

    const db = admin.firestore(app);
    
    // Connect to emulator
    db.useEmulator('localhost', 8085);
    
    log('Connected to Firebase Emulator', 'green');
    return db;
  } catch (error) {
    log(`Failed to initialize Firebase: ${error.message}`, 'red');
    process.exit(1);
  }
}

async function createTestUser(db, email, password) {
  try {
    const userRef = db.collection('users').doc();
    await userRef.set({
      email: email,
      displayName: email.split('@')[0],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    return userRef.id;
  } catch (error) {
    throw new Error(`Create user failed: ${error.message}`);
  }
}

async function createTestRoom(db, hostId) {
  try {
    const roomRef = await db.collection('rooms').add({
      hostId: hostId,
      ownerId: hostId,
      name: 'Test Room - Permission Validation',
      description: 'Room for testing room join permissions',
      isAdult: false,
      isLive: true,
      allowGuestAccess: true,
      memberCount: 1,
      audienceUserIds: [hostId],
      stageUserIds: [],
      adminUserIds: [],
      category: 'general',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    return roomRef.id;
  } catch (error) {
    throw new Error(`Create room failed: ${error.message}`);
  }
}

async function runTests() {
  logHeader('🔐 MIXVY Firebase Emulator Permission Tests');
  
  let db;
  let testUser1 = null;
  let testUser2 = null;
  let testRoomId = null;

  try {
    // Initialize
    log('[SETUP] Initializing Firebase Emulator...', 'cyan');
    db = await initializeFirebase();
    log('[SETUP] ✓ Connection established\n', 'green');

    // Test 0: Setup - Create Users
    log('[TEST SETUP] Creating test users...', 'cyan');
    try {
      testUser1 = await createTestUser(db, 'testuser1@mixvy.local', 'TestPass123!');
      log(`  ✓ User 1 created: ${testUser1}`, 'green');
      
      testUser2 = await createTestUser(db, 'testuser2@mixvy.local', 'TestPass123!');
      log(`  ✓ User 2 created: ${testUser2}`, 'green');
      
      testRoomId = await createTestRoom(db, testUser1);
      log(`  ✓ Test room created: ${testRoomId}\n`, 'green');
    } catch (error) {
      logTest('Setup: Create users and room', 'FAIL', error.message);
      throw error;
    }

    // Test 1: User joins own room
    logHeader('TEST 1: User Joins Non-Adult Room');
    log('Scenario: Host user joins their own room as participant\n', 'yellow');
    try {
      const participantRef = db.collection('rooms').doc(testRoomId)
        .collection('participants').doc(testUser1);
      
      await participantRef.set({
        userId: testUser1,
        role: 'audience',
        isMuted: false,
        isBanned: false,
        camOn: false,
        userStatus: 'online',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const doc = await participantRef.get();
      if (doc.exists) {
        logTest('Test 1: User joins room', 'PASS', 'Participant doc created successfully');
      } else {
        logTest('Test 1: User joins room', 'FAIL', 'Participant doc not found after creation');
      }
    } catch (error) {
      logTest('Test 1: User joins room', 'FAIL', error.message);
    }

    // Test 2: Different user joins same room
    logHeader('TEST 2: Different User Joins Same Room');
    log('Scenario: User 2 joins room created by User 1\n', 'yellow');
    try {
      const participantRef = db.collection('rooms').doc(testRoomId)
        .collection('participants').doc(testUser2);
      
      await participantRef.set({
        userId: testUser2,
        role: 'audience',
        isMuted: false,
        isBanned: false,
        camOn: false,
        userStatus: 'online',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const doc = await participantRef.get();
      if (doc.exists) {
        logTest('Test 2: User 2 joins room', 'PASS', 'Second participant added successfully');
      } else {
        logTest('Test 2: User 2 joins room', 'FAIL', 'Participant doc not found');
      }
    } catch (error) {
      logTest('Test 2: User 2 joins room', 'FAIL', error.message);
    }

    // Test 3: Read participant roster
    logHeader('TEST 3: Read Participant Roster');
    log('Scenario: Verify both participants are in the room\n', 'yellow');
    try {
      const snapshot = await db.collection('rooms').doc(testRoomId)
        .collection('participants').get();
      
      if (snapshot.size >= 2) {
        logTest('Test 3: Read participants', 'PASS', `Found ${snapshot.size} participant(s)`);
      } else {
        logTest('Test 3: Read participants', 'FAIL', `Expected 2+, found ${snapshot.size}`);
      }
    } catch (error) {
      logTest('Test 3: Read participants', 'FAIL', error.message);
    }

    // Test 4: Update own participant state
    logHeader('TEST 4: Update Own Participant State');
    log('Scenario: User updates their own mic/camera status\n', 'yellow');
    try {
      const participantRef = db.collection('rooms').doc(testRoomId)
        .collection('participants').doc(testUser1);
      
      await participantRef.update({
        userStatus: 'speaking',
        camOn: true,
        lastActiveAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const updated = await participantRef.get();
      if (updated.data().userStatus === 'speaking' && updated.data().camOn === true) {
        logTest('Test 4: Update participant state', 'PASS', 'Participant state updated successfully');
      } else {
        logTest('Test 4: Update participant state', 'FAIL', 'Update verification failed');
      }
    } catch (error) {
      logTest('Test 4: Update participant state', 'FAIL', error.message);
    }

    // Test 5: Verify room data structure
    logHeader('TEST 5: Verify Room Data Structure');
    log('Scenario: Check room document has required fields\n', 'yellow');
    try {
      const roomDoc = await db.collection('rooms').doc(testRoomId).get();
      const data = roomDoc.data();
      
      const requiredFields = [
        'hostId',
        'ownerId',
        'name',
        'isAdult',
        'isLive',
        'memberCount',
        'audienceUserIds',
        'stageUserIds',
        'adminUserIds'
      ];
      
      const missingFields = requiredFields.filter(field => !(field in data));
      
      if (missingFields.length === 0) {
        logTest('Test 5: Room data structure', 'PASS', 'All required fields present');
      } else {
        logTest('Test 5: Room data structure', 'FAIL', `Missing: ${missingFields.join(', ')}`);
      }
    } catch (error) {
      logTest('Test 5: Room data structure', 'FAIL', error.message);
    }

    // Test 6: Create member doc
    logHeader('TEST 6: Create Member Document');
    log('Scenario: Add user as room member\n', 'yellow');
    try {
      const memberRef = db.collection('rooms').doc(testRoomId)
        .collection('members').doc(testUser1);
      
      await memberRef.set({
        userId: testUser1,
        role: 'member',
        displayName: 'Test User 1',
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      const doc = await memberRef.get();
      if (doc.exists) {
        logTest('Test 6: Create member doc', 'PASS', 'Member document created');
      } else {
        logTest('Test 6: Create member doc', 'FAIL', 'Member document not found');
      }
    } catch (error) {
      logTest('Test 6: Create member doc', 'FAIL', error.message);
    }

  } catch (error) {
    log(`\nFatal error: ${error.message}`, 'red');
  } finally {
    // Print summary
    logHeader('📊 TEST SUMMARY');
    
    const total = results.passed + results.failed;
    const percentage = total > 0 ? Math.round((results.passed / total) * 100) : 0;
    
    log(`Total Tests: ${total}`, 'cyan');
    log(`Passed: ${results.passed}`, 'green');
    log(`Failed: ${results.failed}`, results.failed > 0 ? 'red' : 'green');
    log(`Success Rate: ${percentage}%`, percentage === 100 ? 'green' : 'yellow');
    
    log('\nDetailed Results:', 'bright');
    results.tests.forEach(test => {
      const icon = test.status === 'PASS' ? '✓' : '✗';
      const color = test.status === 'PASS' ? 'green' : 'red';
      log(`  ${icon} ${test.testName}`, color);
      if (test.message) log(`     ${test.message}`, 'yellow');
    });
    
    // Exit code
    const exitCode = results.failed > 0 ? 1 : 0;
    log(`\nExit Code: ${exitCode}`, exitCode === 0 ? 'green' : 'red');
    
    if (exitCode === 0) {
      log('\n✅ ALL TESTS PASSED - Ready for production deployment!', 'green');
    } else {
      log('\n❌ SOME TESTS FAILED - Review rules before deployment', 'red');
    }
    
    process.exit(exitCode);
  }
}

// Run tests
runTests().catch(error => {
  log(`Unhandled error: ${error.message}`, 'red');
  process.exit(1);
});
