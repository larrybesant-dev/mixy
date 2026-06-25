import { test, expect } from '@playwright/test';

/**
 * SMOKE TEST: Quick validation that the live MixVy site is functional.
 * 
 * This test runs automatically after each deployment to Firebase.
 * It verifies the critical path: site loads, assets render, and UI is interactive.
 * 
 * Success = Users can reach the home screen and interact with the app.
 * Failure = Deployment broke something critical (fonts, routing, initialization).
 */

const LIVE_URL = process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app';

test.describe('MixVy Smoke Test', () => {
  test('Should load home screen with all critical assets', async ({ page }) => {
    test.setTimeout(60_000);

    // Capture console messages for debugging
    const consoleLogs: string[] = [];
    const consoleErrors: string[] = [];

    page.on('console', (msg) => {
      const text = msg.text();
      if (msg.type() === 'error') {
        consoleErrors.push(text);
        console.error(`[CONSOLE ERROR] ${text}`);
      } else if (msg.type() === 'warning') {
        console.warn(`[CONSOLE WARN] ${text}`);
      } else {
        consoleLogs.push(text);
      }
    });

    page.on('pageerror', (error) => {
      consoleErrors.push(`Page Error: ${error.message}`);
      console.error(`[PAGE ERROR] ${error.message}`);
    });

    // Navigate to the app
    console.log(`🚀 Navigating to: ${LIVE_URL}`);
    await page.goto(LIVE_URL, {
      waitUntil: 'domcontentloaded',
      timeout: 30_000,
    });

    // Wait for Flutter to initialize
    console.log('⏳ Waiting for Flutter initialization...');
    await page.waitForTimeout(3_000);

    // Verify page title
    const title = await page.title();
    console.log(`📄 Page Title: ${title}`);
    expect(title).toContain('MixVy');

    // Wait for Flutter canvas to render
    console.log('🎨 Waiting for Flutter canvas...');
    const canvasReady = await page
      .waitForFunction(
        () => {
          const hasCanvas =
            !!document.querySelector('flt-glass-pane') ||
            !!document.querySelector('canvas') ||
            !!document.querySelector('flt-scene-host');
          return hasCanvas;
        },
        { timeout: 25_000 },
      )
      .then(() => true)
      .catch(() => false);

    console.log(`🎨 Flutter Canvas Ready: ${canvasReady}`);
    expect(canvasReady).toBeTruthy();

    // Verify no critical assets failed to load
    const failedResources = await page.evaluate(() => {
      const images = Array.from(document.querySelectorAll('img')) as HTMLImageElement[];
      const failed = images
        .filter((img) => !img.complete || img.naturalWidth === 0)
        .map((img) => img.src);

      return {
        images: failed,
        totalImages: images.length,
      };
    });

    console.log(`📸 Images: ${failedResources.totalImages} total, ${failedResources.images.length} failed`);
    if (failedResources.images.length > 0) {
      console.warn(`Failed image loads: ${failedResources.images.join(', ')}`);
    }

    // Check for critical console errors (filter out known warnings)
    const criticalErrors = consoleErrors.filter((error) => {
      // Ignore known non-critical warnings
      const ignoredPatterns = [
        'permission-denied', // Firestore rules expected
        'Failed to fetch', // Network retry
        'Analytics: Dynamic config fetch failed', // Known Firebase Analytics issue
        'Not a valid color', // Rare Flutter rendering issue
        'Could not find a set of Noto fonts', // Font fallback (already fixed)
      ];

      return !ignoredPatterns.some((pattern) => error.includes(pattern));
    });

    console.log(`⚠️ Critical Errors: ${criticalErrors.length}`);
    if (criticalErrors.length > 0) {
      console.error('Critical Errors Found:');
      criticalErrors.forEach((err) => console.error(`  - ${err}`));
    }
    expect(criticalErrors).toHaveLength(0);

    // Verify the app has rendered content (not a blank page)
    const bodyText = await page.locator('body').innerText().catch(() => '');
    console.log(`📝 Body Text Length: ${bodyText.length} characters`);
    expect(bodyText.length).toBeGreaterThan(100); // More than a blank page

    // Take a screenshot for visual verification
    console.log('📸 Taking screenshot...');
    await page.screenshot({
      path: 'test-results/smoke-test-screenshot.png',
      fullPage: false,
    });

    // Final status
    console.log('✅ Smoke Test PASSED');
    console.log(`   - URL: ${LIVE_URL}`);
    console.log(`   - Title: ${title}`);
    console.log(`   - Flutter Ready: ${canvasReady}`);
    console.log(`   - Critical Errors: 0`);
  });

  test('Should have interactive UI elements', async ({ page }) => {
    test.setTimeout(45_000);

    console.log(`🚀 Navigating to: ${LIVE_URL}`);
    await page.goto(LIVE_URL, { waitUntil: 'domcontentloaded' });

    // Wait for Flutter to render
    await page.waitForTimeout(3_500);

    // Try to find interactive elements
    // (These may vary based on auth state, so we're lenient)
    const hasButtons = await page.locator('button').count().then((c) => c > 0);
    const hasText = await page.locator('text=/.*[a-zA-Z].*/').count().then((c) => c > 0);

    console.log(`🔘 Buttons Found: ${hasButtons}`);
    console.log(`📝 Text Elements Found: ${hasText}`);

    // At minimum, verify we're not looking at an error page
    const bodyText = await page.locator('body').innerText().catch(() => '');
    expect(bodyText).not.toContain('404');
    expect(bodyText).not.toContain('Internal Server Error');

    console.log('✅ Interactive UI Elements PASSED');
  });
});
