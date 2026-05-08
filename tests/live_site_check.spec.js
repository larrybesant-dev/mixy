import { test, expect } from '@playwright/test';

test('Verify MixVy Live Site Rendering', async ({ page }) => {
  // Listen for console messages and errors
  page.on('console', msg => {
    if (msg.type() === 'error') {
      console.log(`BROWSER ERROR: ${msg.text()}`);
    } else {
      console.log(`BROWSER LOG: ${msg.text()}`);
    }
  });

  page.on('pageerror', error => {
    console.log(`BROWSER PAGE ERROR: ${error.message}`);
  });

  const liveUrl = 'https://mix-and-mingle-v2.web.app';
  console.log(`Navigating to: ${liveUrl}`);

  await page.goto(liveUrl, { timeout: 60000 });

  console.log('Waiting for app initialization...');
  await page.waitForTimeout(15000); // Give it 15 seconds to attempt all background syncs

  console.log('Capturing verification screenshot...');
  await page.screenshot({ path: 'test-results/live_site_final_check.png', fullPage: true });

  console.log('✅ Screenshot saved to test-results/live_site_final_check.png');

  await expect(page).toHaveTitle(/MixVy/);
});
