import { test, expect } from '@playwright/test';

test('Verify MixVy Live Site Rendering', async ({ page }) => {
  // 1. Navigate to your live URL
  const liveUrl = 'https://mix-and-mingle-v2.web.app';
  console.log(`Navigating to: ${liveUrl}`);

  // Use a longer timeout for the initial load
  await page.goto(liveUrl, { timeout: 60000 });

  // 2. Wait for the Flutter app to "Hydrate" (load the main view)
  // Flutter Web uses a 'flt-glass-pane' element when it's ready.
  console.log('Waiting for flt-glass-pane...');
  await page.waitForSelector('flt-glass-pane', { timeout: 60000 });

  // 3. Take a screenshot to verify the UI
  console.log('Capturing screenshot...');
  await page.screenshot({ path: 'test-results/live_site_screenshot.png', fullPage: true });

  console.log('✅ Screenshot saved to test-results/live_site_screenshot.png');

  // 4. Basic check: Does the page title contain MixVy?
  await expect(page).toHaveTitle(/MixVy/);
});
