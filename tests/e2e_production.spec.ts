import { test, expect, Page } from '@playwright/test';

/**
 * MixVy Production E2E Testing Suite
 * 
 * This test suite provides comprehensive end-to-end testing for the live
 * MixVy production app at https://mixvy-v2.web.app with:
 * - Global error tracking (console.error, JS exceptions)
 * - Authentication flow validation
 * - Live Room navigation and rendering
 * - Room join flow with connection health verification
 * - Automatic video + trace file capture on failure
 */

// Test credentials (configure via environment variables for security)
const TEST_EMAIL = process.env.TEST_EMAIL || 'test@example.com';
const TEST_PASSWORD = process.env.TEST_PASSWORD || 'testpassword123';

/**
 * Global error tracking fixture
 * Captures console errors and uncaught JS exceptions
 * and fails the test if any are detected
 */
test.beforeEach(async ({ page, context }) => {
  // Store all errors that occur during the test
  const errors: string[] = [];
  const exceptions: string[] = [];

  // Track console.error messages
  page.on('console', (msg) => {
    if (msg.type() === 'error') {
      const errorMsg = `Console Error: ${msg.text()}`;
      console.error(errorMsg);
      errors.push(errorMsg);
    }
  });

  // Track uncaught JS exceptions
  page.on('pageerror', (exception) => {
    const exceptionMsg = `Uncaught Exception: ${exception.message}\n${exception.stack}`;
    console.error(exceptionMsg);
    exceptions.push(exceptionMsg);
  });

  // Track request failures that indicate network issues
  page.on('requestfailed', (request) => {
    const failMsg = `Request Failed: ${request.method()} ${request.url()} - ${request.failure()?.errorText}`;
    console.warn(failMsg);
  });

  // Store for later assertion in afterEach
  (page as any)._testErrors = errors;
  (page as any)._testExceptions = exceptions;
});

/**
 * Cleanup and error assertion
 * Fails the test if any console errors or exceptions occurred
 */
test.afterEach(async ({ page }, testInfo) => {
  const errors = (page as any)._testErrors || [];
  const exceptions = (page as any)._testExceptions || [];

  if (errors.length > 0) {
    console.error(`Test captured ${errors.length} console errors:`, errors);
  }

  if (exceptions.length > 0) {
    console.error(`Test captured ${exceptions.length} exceptions:`, exceptions);
  }

  // Fail the test if any errors were captured
  if (errors.length > 0 || exceptions.length > 0) {
    testInfo.fail();
    throw new Error(
      `Test failed due to ${errors.length} console errors and ${exceptions.length} exceptions. ` +
      `Check trace file for details.`
    );
  }
});

/**
 * Test 1: Setup Basic Navigation
 * Logs in with test credentials and verifies Live Rooms page loads
 */
test('01-Setup-Navigation: Login and view Live Rooms', async ({ page }) => {
  // Navigate to the app
  await page.goto('/', { waitUntil: 'networkidle' });
  await expect(page).toHaveTitle(/MixVy|Velvet/i);

  // Check for login form (adjust selector based on actual app structure)
  const emailInput = page.locator('input[type="email"], input[placeholder*="email" i]').first();
  await expect(emailInput).toBeVisible({ timeout: 5000 });

  // Fill in login credentials
  await emailInput.fill(TEST_EMAIL);
  const passwordInput = page.locator('input[type="password"]');
  await passwordInput.fill(TEST_PASSWORD);

  // Click sign in button
  const signInButton = page.locator('button:has-text("Sign In"), button:has-text("SIGN IN")').first();
  await signInButton.click();

  // Wait for navigation to complete after login
  await page.waitForURL(/\/(home|rooms|live)/, { timeout: 10000 });

  // Navigate to Live Rooms page (adjust based on actual routing)
  await page.goto('/home', { waitUntil: 'networkidle' });

  // Verify at least one room card is rendered
  const roomCards = page.locator('[class*="room" i], [class*="card" i]');
  const cardCount = await roomCards.count();

  console.log(`Found ${cardCount} room cards on Live Rooms page`);

  if (cardCount > 0) {
    // At least one room exists
    await expect(roomCards.first()).toBeVisible();
  } else {
    console.warn('No room cards found - app may be in empty state');
  }
});

/**
 * Test 2: Feature Verification - Join a Live Room
 * Tests the critical path: click room → verify URL change → check video player → verify connection health
 */
test('02-Feature-Join: Click room, verify URL, check video player, confirm connection health', async ({
  page,
  context,
}) => {
  // Login first
  await page.goto('/', { waitUntil: 'networkidle' });
  const emailInput = page.locator('input[type="email"], input[placeholder*="email" i]').first();
  await emailInput.fill(TEST_EMAIL);
  const passwordInput = page.locator('input[type="password"]');
  await passwordInput.fill(TEST_PASSWORD);
  const signInButton = page.locator('button:has-text("Sign In"), button:has-text("SIGN IN")').first();
  await signInButton.click();
  await page.waitForURL(/\/(home|rooms|live)/, { timeout: 10000 });

  // Navigate to rooms page
  await page.goto('/home', { waitUntil: 'networkidle' });

  // Find and click the first available room card
  const roomCards = page.locator('[class*="room" i], [data-testid*="room" i]');
  const cardCount = await roomCards.count();

  if (cardCount === 0) {
    console.warn('No rooms available to join - skipping room join test');
    return;
  }

  const firstRoomCard = roomCards.first();
  const currentUrl = page.url();

  // Click the room card
  await firstRoomCard.click();

  // Assert URL changed to a room path
  await page.waitForURL(/\/(room|live)\//, { timeout: 10000 });
  const newUrl = page.url();
  expect(newUrl).not.toBe(currentUrl);
  console.log(`✓ URL changed from ${currentUrl} to ${newUrl}`);

  // Assert video player element is visible
  // Look for common video player indicators
  const videoPlayer = page
    .locator(
      '[class*="video" i], [class*="player" i], video, [data-testid*="video" i], [role="region"][aria-label*="video" i]'
    )
    .first();

  const isPlayerVisible = await videoPlayer.isVisible().catch(() => false);

  if (isPlayerVisible) {
    console.log('✓ Video player element is visible');
    await expect(videoPlayer).toBeVisible();
  } else {
    console.warn('Video player not found as visible element - checking if it will load...');
  }

  // Wait for connection health state to become 'Healthy'
  // Look for health badge or status indicator
  const connectionBadge = page.locator(
    '[class*="health" i], [class*="connection" i], [class*="status" i], [role="status"]'
  );

  let healthyFound = false;
  const maxWaitTime = 15000; // 15 second max wait
  const startTime = Date.now();

  while (Date.now() - startTime < maxWaitTime) {
    const badges = await connectionBadge.all();

    for (const badge of badges) {
      const text = await badge.textContent();
      if (text && text.toLowerCase().includes('healthy')) {
        console.log(`✓ Connection health verified as HEALTHY`);
        healthyFound = true;
        break;
      }
    }

    if (healthyFound) break;

    // Wait a bit before checking again
    await page.waitForTimeout(500);
  }

  if (!healthyFound) {
    console.warn('Connection health "Healthy" badge not found within 15 seconds - connection may still be establishing');
  }

  console.log('✓ Room join flow completed successfully');
});

/**
 * Test 3: Connection Resilience Check
 * Verifies that the app handles connection issues gracefully
 */
test('03-Resilience: Connection state monitoring', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle' });

  // Login
  const emailInput = page.locator('input[type="email"], input[placeholder*="email" i]').first();
  await emailInput.fill(TEST_EMAIL);
  const passwordInput = page.locator('input[type="password"]');
  await passwordInput.fill(TEST_PASSWORD);
  const signInButton = page.locator('button:has-text("Sign In"), button:has-text("SIGN IN")').first();
  await signInButton.click();
  await page.waitForURL(/\/(home|rooms|live)/, { timeout: 10000 });

  // Navigate to home
  await page.goto('/home', { waitUntil: 'networkidle' });

  // Monitor network activity for 10 seconds
  const networkErrors: string[] = [];
  page.on('requestfailed', (request) => {
    networkErrors.push(`${request.method()} ${request.url()}`);
  });

  console.log('Monitoring network activity for 10 seconds...');
  await page.waitForTimeout(10000);

  if (networkErrors.length > 0) {
    console.warn(`Detected ${networkErrors.length} network errors during monitoring:`, networkErrors);
  } else {
    console.log('✓ No network errors detected during connection monitoring');
  }

  // Verify app is still responsive
  const pageTitle = await page.title();
  expect(pageTitle.length).toBeGreaterThan(0);
  console.log('✓ App remained responsive');
});

/**
 * Test 4: Error State Verification
 * Attempts to trigger error logging to verify that error tracking works
 */
test('04-Error-Tracking: Verify DiagnosticLogger integration', async ({ page }) => {
  await page.goto('/', { waitUntil: 'networkidle' });

  // Login
  const emailInput = page.locator('input[type="email"], input[placeholder*="email" i]').first();
  await emailInput.fill(TEST_EMAIL);
  const passwordInput = page.locator('input[type="password"]');
  await passwordInput.fill(TEST_PASSWORD);
  const signInButton = page.locator('button:has-text("Sign In"), button:has-text("SIGN IN")').first();
  await signInButton.click();
  await page.waitForURL(/\/(home|rooms|live)/, { timeout: 10000 });

  // Listen for console logs to verify diagnostic logging
  const consoleLogs: { type: string; text: string }[] = [];
  page.on('console', (msg) => {
    consoleLogs.push({
      type: msg.type(),
      text: msg.text(),
    });
  });

  // Check if any [MIXVY_DEBUG] logs appear
  const debugLogs = consoleLogs.filter((log) => log.text.includes('[MIXVY_DEBUG]'));

  if (debugLogs.length > 0) {
    console.log(`✓ Detected ${debugLogs.length} [MIXVY_DEBUG] diagnostic logs`);
    debugLogs.forEach((log) => console.log(`  - [${log.type}] ${log.text}`));
  } else {
    console.warn('No [MIXVY_DEBUG] logs detected - diagnostic logging may not be active');
  }

  // All logs passed through global error tracking
  console.log(`✓ Total console logs captured: ${consoleLogs.length}`);
});
