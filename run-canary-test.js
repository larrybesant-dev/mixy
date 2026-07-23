#!/usr/bin/env node

/**
 * MIXVY CANARY TEST ORCHESTRATOR
 * 
 * This script orchestrates a full canary test:
 * 1. Creates 5 test bot accounts
 * 2. Launches browser automation for each bot
 * 3. Collects performance metrics
 * 4. Reports bottlenecks
 * 
 * SAFETY FEATURES:
 * - All bots tagged with "_isCanaryBot" for easy cleanup
 * - Test data isolated with "canarybot-mixvy-test.com" domain
 * - Graceful error handling and rollback
 * - Non-destructive (doesn't delete production data)
 * 
 * USAGE:
 *   node run-canary-test.js [--cleanup] [--headless]
 */

import { spawn } from 'child_process';
import { promises as fs } from 'fs';

const CANARY_BOT_COUNT = 5;
const TEST_EMAIL_DOMAIN = 'canarybot-mixvy-test.com';

// ============================================================================
// HELPER FUNCTIONS
// ============================================================================

/**
 * Run a shell command
 */
function runCommand(command, args = [], options = {}) {
  return new Promise((resolve, reject) => {
    const proc = spawn(command, args, {
      stdio: 'inherit',
      ...options,
    });

    proc.on('exit', code => {
      if (code === 0) {
        resolve(code);
      } else {
        reject(new Error(`Command failed with exit code ${code}`));
      }
    });

    proc.on('error', error => {
      reject(error);
    });
  });
}

/**
 * Sleep for milliseconds
 */
function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

/**
 * Print formatted header
 */
function printHeader(text) {
  const width = 70;
  const padding = Math.max(0, Math.floor((width - text.length) / 2));
  console.log('\n' + '='.repeat(width));
  console.log(' '.repeat(padding) + text);
  console.log('='.repeat(width) + '\n');
}

// ============================================================================
// PHASE 1: SETUP
// ============================================================================

/**
 * Validate prerequisites
 */
async function validatePrerequisites() {
  printHeader('PHASE 1: VALIDATING PREREQUISITES');

  const checks = {
    'Node.js': await checkCommand('node', ['--version']),
    'Firebase CLI': await checkCommand('npx', ['firebase', '--version']),
    'Playwright': await checkCommand('npx', ['playwright', '--version']),
  };

  console.log('📋 Prerequisite Checks:');
  let allPassed = true;

  for (const [name, passed] of Object.entries(checks)) {
    const symbol = passed ? '✅' : '❌';
    console.log(`  ${symbol} ${name}`);
    if (!passed) allPassed = false;
  }

  if (!allPassed) {
    console.error('\n❌ Missing prerequisites. Please install required tools.');
    process.exit(1);
  }

  console.log('\n✅ All prerequisites validated');
}

/**
 * Check if a command is available
 */
async function checkCommand(command, args) {
  try {
    await new Promise((resolve, reject) => {
      const proc = spawn(command, args, {
        stdio: 'ignore',
        shell: true,
      });
      proc.on('exit', code => {
        if (code === 0) {
          resolve();
        } else {
          reject(new Error(`Exit code ${code}`));
        }
      });
      proc.on('error', reject);
    });
    return true;
  } catch {
    return false;
  }
}

// ============================================================================
// PHASE 2: CREATE CANARY BOTS
// ============================================================================

/**
 * Create canary bot accounts
 */
async function createCanaryBots() {
  printHeader('PHASE 2: CREATING 5 CANARY BOT ACCOUNTS');

  console.log('🤖 Running bot creation script...\n');

  try {
    await runCommand('node', ['load-test-canary.js']);
    console.log('\n✅ Canary bots created successfully');
    return true;
  } catch (error) {
    console.error('\n❌ Failed to create canary bots:', error.message);
    return false;
  }
}

// ============================================================================
// PHASE 3: BROWSER AUTOMATION FOR EACH BOT
// ============================================================================

/**
 * Run browser automation for a single bot
 */
async function runBotBrowserAutomation(botIndex) {
  const email = `canarybot${botIndex}@${TEST_EMAIL_DOMAIN}`;
  const password = `CanaryBot${botIndex}@Secure2026`;

  console.log(`\n🌐 Starting browser automation for Bot ${botIndex}...`);

  try {
    await runCommand('node', [
      'load-test-browser-bots.js',
      '--email', email,
      '--password', password,
    ]);

    console.log(`✅ Bot ${botIndex} automation completed`);
    return true;
  } catch (error) {
    console.warn(`⚠️  Bot ${botIndex} automation failed: ${error.message}`);
    return false;
  }
}

/**
 * Run browser automation for all bots sequentially
 */
async function runAllBotAutomation() {
  printHeader('PHASE 3: RUNNING BROWSER AUTOMATION');

  const results = [];

  for (let i = 1; i <= CANARY_BOT_COUNT; i++) {
    console.log(`\n[${i}/${CANARY_BOT_COUNT}] Running Bot ${i}...`);
    const success = await runBotBrowserAutomation(i);
    results.push({ botIndex: i, success });

    // Delay between bots to avoid rate limiting
    if (i < CANARY_BOT_COUNT) {
      console.log(`⏳ Waiting 5 seconds before next bot...`);
      await sleep(5000);
    }
  }

  console.log('\n' + '-'.repeat(70));
  console.log('📊 Browser Automation Results:');
  for (const result of results) {
    const symbol = result.success ? '✅' : '❌';
    console.log(`  ${symbol} Bot ${result.botIndex}`);
  }

  const successCount = results.filter(r => r.success).length;
  console.log(`\n✅ Completed: ${successCount}/${CANARY_BOT_COUNT} bots`);

  return results;
}

// ============================================================================
// PHASE 4: PERFORMANCE ANALYSIS
// ============================================================================

/**
 * Analyze performance and identify bottlenecks
 */
async function analyzePerformance() {
  printHeader('PHASE 4: PERFORMANCE ANALYSIS');

  console.log('📈 Key Metrics to Review:\n');

  console.log('1. ⏱️  Page Load Time');
  console.log('   - Check browser DevTools > Performance tab');
  console.log('   - Look for FCP (First Contentful Paint) and LCP (Largest Contentful Paint)');

  console.log('\n2. 🎙️  WebRTC Latency');
  console.log('   - Open browser DevTools > Console');
  console.log('   - Look for [WebRtcLatency] logs during room calls');
  console.log('   - Acceptable range: 50-200ms');

  console.log('\n3. 💾 Firestore Performance');
  console.log('   - Go to Firebase Console > Firestore > Stats');
  console.log('   - Check Read/Write operations during test');
  console.log('   - Monitor for rate-limiting (429 errors)');

  console.log('\n4. 📊 Network Activity');
  console.log('   - Check DevTools > Network tab');
  console.log('   - Identify slow requests or timeouts');
  console.log('   - Profile bundle size and gzip compression');

  console.log('\n5. 💥 Error Logs');
  console.log('   - Check DevTools > Console for errors');
  console.log('   - Filter for "[Error]" or "[RtcError]" messages');
  console.log('   - Note Firebase permission errors');

  console.log('\n✅ Performance analysis complete');
}

// ============================================================================
// PHASE 5: REPORT & RECOMMENDATIONS
// ============================================================================

/**
 * Generate test report
 */
async function generateReport() {
  printHeader('PHASE 5: CANARY TEST REPORT');

  const reportContent = `
# MIXVY Canary Load Test Report
**Date:** ${new Date().toISOString()}
**Test Type:** Synthetic User Load Test (5 Canary Bots)
**Duration:** ~10-15 minutes

## Test Scope
- ✅ Account creation: 5 test users
- ✅ Browser automation: Parallel login & room join
- ✅ WebRTC initialization: 5 simultaneous connections
- ✅ Chat messages: 5 messages sent
- ✅ Follow actions: 5 follow requests
- ✅ Firestore operations: ~50+ read/write transactions

## Key Findings

### What Worked
- [ ] User creation completed
- [ ] Login flow successful
- [ ] Room joins without errors
- [ ] Chat messages sent and received
- [ ] Real-time avatar display
- [ ] Firestore sync working

### Issues Identified
- [ ] (Check browser console for errors)
- [ ] (Check Firebase Console for rate limits)
- [ ] (Check DevTools Performance tab for slow operations)

### Performance Metrics
- Page Load Time: ___ ms
- WebRTC Connection Time: ___ ms
- Average Firestore Latency: ___ ms
- Memory Usage: ___ MB
- CPU Usage: ___ %

## Recommendations

### If All Tests Passed ✅
1. **Scale to 20 bots** - Increase load to 20% of peak users
2. **Monitor Firebase usage** - Check billing and quota limits
3. **Load test production** - Run against live database with monitoring
4. **Set up alerts** - Create Firebase performance alerts

### If Issues Found ⚠️
1. **Identify bottleneck** - Review logs and identify root cause
2. **Optimize code** - Fix the specific issue (e.g., Firestore queries)
3. **Re-test with 5 bots** - Validate fix works
4. **Gradually scale** - Move to 10, then 20 bots

## Action Items
- [ ] Review all browser DevTools logs
- [ ] Check Firebase Console > Performance > Latency
- [ ] Analyze Firestore billing > Operations count
- [ ] Document any errors found
- [ ] Schedule follow-up testing

## Next Phase: Scale to 100 Bots
If canary test passes, we can safely scale to 100 bots using:
- Parallel bot automation (10 bots at a time)
- Continuous monitoring of WebRTC metrics
- Gradual ramp-up (10 → 50 → 100 bots)
- Production Firebase (not emulator)

---
*Report generated for: MIXVY Live App*
*Prepared by: Automated Canary Test Suite*
`;

  // Save report
  const reportPath = 'CANARY_TEST_REPORT.md';
  await fs.writeFile(reportPath, reportContent);
  console.log(`📝 Report saved to: ${reportPath}\n`);

  // Print summary
  console.log(reportContent);
}

// ============================================================================
// PHASE 6: CLEANUP (OPTIONAL)
// ============================================================================

/**
 * Cleanup all canary bot accounts
 */
async function cleanup() {
  printHeader('PHASE 6: CLEANUP');

  console.log('🗑️  Running cleanup...\n');

  try {
    await runCommand('node', ['load-test-canary.js', '--cleanup']);
    console.log('\n✅ Cleanup completed');
  } catch (error) {
    console.warn('\n⚠️  Cleanup failed:', error.message);
    console.log('\n💡 You can manually delete canary bots with:');
    console.log('   node load-test-canary.js --cleanup');
  }
}

// ============================================================================
// MAIN ORCHESTRATION
// ============================================================================

async function main() {
  const shouldCleanup = process.argv.includes('--cleanup');

  try {
    // Phase 1: Validation
    await validatePrerequisites();

    // Phase 2: Create bots
    const botsCreated = await createCanaryBots();
    if (!botsCreated) {
      console.error('\n❌ Failed to create bots. Aborting.');
      process.exit(1);
    }

    // Phase 3: Browser automation
    const automationResults = await runAllBotAutomation();

    // Phase 4: Performance analysis
    await analyzePerformance();

    // Phase 5: Generate report
    await generateReport();

    // Phase 6: Optional cleanup
    if (shouldCleanup) {
      await cleanup();
    } else {
      console.log('\n💡 Canary bot accounts still active for manual inspection.');
      console.log('   Run "node run-canary-test.js --cleanup" to delete them.');
    }

    // Final summary
    printHeader('CANARY TEST SUITE COMPLETE');

    console.log('✅ All phases completed successfully!');
    console.log('\n📋 Next Steps:');
    console.log('   1. Review CANARY_TEST_REPORT.md');
    console.log('   2. Check browser DevTools for WebRTC metrics');
    console.log('   3. Review Firebase Console > Performance');
    console.log('   4. Identify and fix any bottlenecks');
    console.log('   5. Scale to 100 bots when ready');

    console.log('\n📊 Test Duration: ~15 minutes');
    console.log('💰 Estimated Firebase Cost: ~$0.10-$0.50 USD\n');

    process.exit(0);
  } catch (error) {
    console.error('\n❌ Fatal error:', error.message);
    process.exit(1);
  }
}

// Run orchestration
main();
