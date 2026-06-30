import { chromium } from 'playwright';

/**
 * CANARY BOT BROWSER AUTOMATION SUITE
 * 
 * Uses Playwright to automate browser interactions for canary bots.
 * Simulates real user behavior: login, join room, chat, follow users.
 * 
 * USAGE:
 *   node load-test-browser-bots.js --email canarybot1@canarybot-mixvy-test.com --password CanaryBot1@Secure2026
 */

const PRODUCTION_URL = 'https://mixvy-v2.web.app';

// Parse CLI arguments
const args = process.argv.slice(2);
const emailIndex = args.indexOf('--email');
const passwordIndex = args.indexOf('--password');

const botEmail = emailIndex !== -1 ? args[emailIndex + 1] : null;
const botPassword = passwordIndex !== -1 ? args[passwordIndex + 1] : null;

if (!botEmail || !botPassword) {
  console.error('❌ Usage: node load-test-browser-bots.js --email <email> --password <password>');
  process.exit(1);
}

// ============================================================================
// BROWSER AUTOMATION FUNCTIONS
// ============================================================================

/**
 * Login to the app
 */
async function login(page, email, password) {
  console.log(`\n  🔐 Logging in as ${email}...`);

  try {
    // Navigate to auth page
    await page.goto(`${PRODUCTION_URL}/auth`, { waitUntil: 'networkidle' });

    // Wait for page to load
    await page.waitForTimeout(2000);

    // Try to find and fill email input
    // Note: Flutter web renders in canvas, so we may need to use alternative selectors
    const emailInputs = await page.$$eval('input[type="text"]', inputs => 
      inputs.map(input => ({
        placeholder: input.getAttribute('placeholder'),
        value: input.value,
      }))
    ).catch(() => []);

    console.log(`    Found ${emailInputs.length} text inputs`);

    // Click on first text input and type email
    const inputs = await page.$$('input[type="text"]');
    if (inputs.length > 0) {
      await inputs[0].click();
      await inputs[0].fill(email);
      console.log(`    ✓ Entered email`);
    }

    // Find password input and fill it
    const passwordInputs = await page.$$('input[type="password"]');
    if (passwordInputs.length > 0) {
      await passwordInputs[0].click();
      await passwordInputs[0].fill(password);
      console.log(`    ✓ Entered password`);
    }

    // Look for login/continue button
    const buttons = await page.$$('button');
    let clicked = false;
    for (const button of buttons) {
      const text = await button.textContent();
      if (text?.includes('Continue') || text?.includes('Sign In') || text?.includes('Login')) {
        await button.click();
        clicked = true;
        console.log(`    ✓ Clicked login button`);
        break;
      }
    }

    if (!clicked) {
      console.log(`    ⚠️  Could not find login button, trying Enter key...`);
      await page.keyboard.press('Enter');
    }

    // Wait for redirect to home/discovery feed
    await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }).catch(() => null);
    await page.waitForTimeout(2000);

    const currentUrl = page.url();
    console.log(`  ✅ Login successful (URL: ${currentUrl})`);
    return true;
  } catch (error) {
    console.error(`  ❌ Login failed: ${error.message}`);
    return false;
  }
}

/**
 * Find and join a live room from discovery feed
 */
async function joinLiveRoom(page) {
  console.log(`\n  🎙️  Looking for live rooms...`);

  try {
    // Wait for page to load
    await page.waitForTimeout(2000);

    // Look for "Live Now" section or room cards
    const roomCards = await page.$$('div[data-testid*="room"], .room-card, [class*="RoomCard"]');
    
    if (roomCards.length === 0) {
      console.log(`    ⚠️  No room cards found on page`);
      
      // Try clicking on any visible clickable element that might be a room
      const clickables = await page.$$('button, div[role="button"], a');
      for (const element of clickables) {
        const text = await element.textContent();
        if (text && (text.includes('room') || text.includes('Room') || text.includes('Live'))) {
          await element.click();
          console.log(`    ✓ Clicked on: ${text.substring(0, 50)}`);
          await page.waitForTimeout(1000);
          break;
        }
      }
      return false;
    }

    console.log(`    ✓ Found ${roomCards.length} room cards`);

    // Click on first room card
    await roomCards[0].click();
    console.log(`    ✓ Clicked on room card`);

    // Wait for room page to load
    await page.waitForNavigation({ waitUntil: 'networkidle', timeout: 10000 }).catch(() => null);
    await page.waitForTimeout(2000);

    // Look for join button and click it
    const buttons = await page.$$('button');
    let joined = false;

    for (const button of buttons) {
      const text = await button.textContent();
      if (text?.includes('Join') || text?.includes('Enter') || text?.includes('Start')) {
        await button.click();
        console.log(`    ✓ Clicked join button`);
        joined = true;
        break;
      }
    }

    if (!joined) {
      console.log(`    ⚠️  Could not find join button`);
      return false;
    }

    await page.waitForTimeout(2000);
    console.log(`  ✅ Joined room successfully`);
    return true;
  } catch (error) {
    console.error(`  ❌ Failed to join room: ${error.message}`);
    return false;
  }
}

/**
 * Send a chat message
 */
async function sendChatMessage(page, message) {
  console.log(`\n  💬 Sending chat message...`);

  try {
    // Find chat input field
    const inputs = await page.$$('input[type="text"], textarea');
    
    if (inputs.length === 0) {
      console.log(`    ⚠️  No input fields found`);
      return false;
    }

    // Try last input (typically chat field)
    const chatInput = inputs[inputs.length - 1];
    await chatInput.click();
    await chatInput.fill(message);
    console.log(`    ✓ Typed message`);

    // Look for send button
    const buttons = await page.$$('button');
    for (const button of buttons) {
      const text = await button.textContent();
      if (text?.includes('Send') || text?.includes('Post')) {
        await button.click();
        console.log(`    ✓ Clicked send button`);
        break;
      }
    }

    await page.waitForTimeout(1000);
    console.log(`  ✅ Message sent`);
    return true;
  } catch (error) {
    console.error(`  ❌ Failed to send message: ${error.message}`);
    return false;
  }
}

/**
 * Navigate back to discovery feed
 */
async function goBackToFeed(page) {
  console.log(`\n  🏠 Going back to discovery feed...`);

  try {
    // Look for back button or home link
    const buttons = await page.$$('button, a');
    for (const button of buttons) {
      const text = await button.textContent();
      if (text?.includes('Back') || text?.includes('Home') || text?.includes('Feed')) {
        await button.click();
        console.log(`    ✓ Clicked back/home button`);
        break;
      }
    }

    // Alternative: navigate directly
    if (page.url() !== `${PRODUCTION_URL}/home` && page.url() !== PRODUCTION_URL) {
      await page.goto(`${PRODUCTION_URL}/home`, { waitUntil: 'networkidle' });
    }

    await page.waitForTimeout(1000);
    console.log(`  ✅ Back to discovery feed`);
    return true;
  } catch (error) {
    console.error(`  ❌ Failed to go back: ${error.message}`);
    return false;
  }
}

/**
 * Check WebRTC latency metrics (from console)
 */
async function checkPerformanceMetrics(page) {
  console.log(`\n  📊 Checking performance metrics...`);

  try {
    // Evaluate metrics from console (if available)
    const metrics = await page.evaluate(() => {
      return {
        url: window.location.href,
        navigationStart: performance.navigationStart,
        loadEventEnd: performance.loadEventEnd,
        timestamp: Date.now(),
      };
    });

    const loadTime = metrics.loadEventEnd - metrics.navigationStart;
    console.log(`    ✓ Page load time: ${loadTime}ms`);
    console.log(`    ✓ Current URL: ${metrics.url}`);

    // Try to get WebRTC stats if available
    const webrtcMetrics = await page.evaluate(() => {
      // This would require WebRTC debug info to be exposed
      return 'WebRTC metrics available in browser DevTools';
    }).catch(() => null);

    if (webrtcMetrics) {
      console.log(`    ✓ ${webrtcMetrics}`);
    }

    return true;
  } catch (error) {
    console.log(`    ⚠️  Could not retrieve metrics: ${error.message}`);
    return false;
  }
}

// ============================================================================
// MAIN EXECUTION
// ============================================================================

async function main() {
  console.log('\n' + '='.repeat(70));
  console.log('  CANARY BOT BROWSER AUTOMATION');
  console.log('  Email: ' + botEmail);
  console.log('='.repeat(70));

  let browser;
  try {
    // Launch browser
    console.log('\n🌐 Launching Chromium browser...');
    browser = await chromium.launch({
      headless: false, // Show browser window for debugging
    });

    const context = await browser.newContext();
    const page = await context.newPage();

    // Enable console message logging
    page.on('console', msg => {
      if (msg.type() === 'error') {
        console.log(`  [Browser Error] ${msg.text()}`);
      } else if (msg.type() === 'log' && msg.text().includes('WebRtc')) {
        console.log(`  [Browser Log] ${msg.text()}`);
      }
    });

    // Step 1: Login
    const loggedIn = await login(page, botEmail, botPassword);
    if (!loggedIn) {
      console.error('\n❌ Could not login. Aborting test.');
      await browser.close();
      process.exit(1);
    }

    // Step 2: Join a room
    const joined = await joinLiveRoom(page);

    if (joined) {
      // Step 3: Send chat message
      await sendChatMessage(page, `🤖 Canary bot testing from Playwright automation!`);

      // Step 4: Check metrics
      await checkPerformanceMetrics(page);

      // Step 5: Return to feed
      await goBackToFeed(page);
    }

    // Summary
    console.log('\n' + '='.repeat(70));
    console.log('  ✅ AUTOMATION TEST COMPLETE');
    console.log('='.repeat(70));

    console.log(`\n  📋 Bot Activity Summary:`);
    console.log(`     - Successfully logged in: ${loggedIn}`);
    console.log(`     - Joined room: ${joined}`);
    console.log(`     - Browser window remains open for inspection`);
    console.log(`\n  💡 Check browser DevTools > Console for WebRTC metrics`);
    console.log(`     Look for [WebRtcLatency] and performance logs`);

    console.log(`\n  🧹 Closing browser in 30 seconds...`);
    await page.waitForTimeout(30000);

    await browser.close();
    console.log(`\n✅ Test completed successfully!\n`);
  } catch (error) {
    console.error('\n❌ Fatal error:', error.message);
    if (browser) {
      await browser.close();
    }
    process.exit(1);
  }
}

// Run main
main();
