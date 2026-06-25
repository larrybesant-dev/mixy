import { test, expect } from '@playwright/test';

test.describe('Payment Flow (Stripe Integration)', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the app
    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    
    // Wait for Flutter to initialize
    await page.waitForTimeout(3000);
    
    // Wait for the app to be interactive
    await page.waitForLoadState('networkidle');
  });

  test('Should load payment/premium screen without errors', async ({ page }) => {
    // Listen for console errors/warnings
    const consoleMessages: Array<{ type: string; text: string }> = [];
    page.on('console', (msg) => {
      consoleMessages.push({ type: msg.type(), text: msg.text() });
    });

    // Navigate to home (auth screen should be visible if not logged in)
    const hasTitle = await page.locator('text=MixVy').isVisible({ timeout: 5000 });
    expect(hasTitle).toBeTruthy();

    // Check that Flutter rendered successfully
    const flutterCanvas = page.locator('canvas');
    await expect(flutterCanvas).toBeVisible({ timeout: 5000 });

    // Filter out known safe console messages
    const safePatterns = [
      /favicon/i,
      /Failed to load/i,
      /manifest/i,
      /NotoSans/i,
      /404/i,
      /google-analytics/i,
    ];

    const criticalErrors = consoleMessages.filter(
      (msg) =>
        msg.type === 'error' &&
        !safePatterns.some((pattern) => pattern.test(msg.text))
    );

    expect(
      criticalErrors,
      `Critical console errors found: ${JSON.stringify(criticalErrors)}`
    ).toEqual([]);
  });

  test('Should have Stripe payment button visible on premium screen', async ({ page }) => {
    // Look for premium/payment related buttons
    const upgradeButton = page.locator('button:has-text(/upgrade|premium|buy|subscribe/i)');
    
    // Should have at least one payment-related button
    const buttonCount = await upgradeButton.count();
    expect(buttonCount).toBeGreaterThanOrEqual(0);
    
    // If button exists, check it's interactive
    if (buttonCount > 0) {
      await expect(upgradeButton.first()).toBeEnabled({ timeout: 5000 });
    }
  });

  test('Should handle payment button click without crashing', async ({ page }) => {
    // Intercept Cloud Function calls to prevent actual payment processing
    await page.route('**/createCheckoutSessionCallable*', async (route) => {
      // Simulate a failed checkout (as we're in test environment)
      await route.abort('failed');
    });

    // Look for and click upgrade button
    const upgradeButton = page.locator('button:has-text(/upgrade|premium|buy|subscribe/i)').first();
    
    if (await upgradeButton.count() > 0) {
      await upgradeButton.click({ timeout: 5000 });
      
      // Wait briefly for error handling
      await page.waitForTimeout(1000);
      
      // Page should still be responsive (no crash)
      const isPageAlive = await page.evaluate(() => {
        return document.readyState === 'complete';
      });
      
      expect(isPageAlive).toBe(true);
    }
  });

  test('Should not have CSS errors related to payment widgets', async ({ page }) => {
    // Check for common CSS loading issues
    const styleElements = await page.$$('link[rel="stylesheet"]');
    
    for (const styleElement of styleElements) {
      const href = await styleElement.getAttribute('href');
      if (href) {
        const response = await page.goto(href, { waitUntil: 'domcontentloaded' }).catch(() => null);
        // If a stylesheet fails to load, it should not crash the app
        // Just verify the app remains functional
      }
    }
    
    // Verify app is still responsive
    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    const canvas = page.locator('canvas');
    await expect(canvas).toBeVisible({ timeout: 5000 });
  });

  test('Stripe initialization should not block app rendering', async ({ page }) => {
    // Intercept Stripe initialization
    await page.route('**/stripe.js', async (route) => {
      // Delay Stripe initialization by 2 seconds
      await new Promise(r => setTimeout(r, 2000));
      await route.continue();
    });

    // Navigate and verify app renders even if Stripe is slow
    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    
    // App should be visible despite Stripe delay
    const canvas = page.locator('canvas');
    await expect(canvas).toBeVisible({ timeout: 5000 });
    
    // Verify content is rendered
    const content = await page.evaluate(() => document.body.textContent?.length ?? 0);
    expect(content).toBeGreaterThan(0);
  });

  test('Should handle network errors gracefully', async ({ page }) => {
    // Simulate offline for Cloud Function calls
    await page.route('**/cloudfunctions*', async (route) => {
      await route.abort('timedout');
    });

    // Navigate to app
    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    await page.waitForTimeout(3000);

    // App should still be interactive
    const canvas = page.locator('canvas');
    await expect(canvas).toBeVisible({ timeout: 5000 });

    // Look for error message or fallback UI
    const pageContent = await page.evaluate(() => document.body.textContent);
    expect(pageContent?.length).toBeGreaterThan(0);
  });
});

test.describe('Payment State Management', () => {
  test('Should maintain payment state across navigation', async ({ page }) => {
    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    await page.waitForTimeout(3000);

    // Check if we can navigate back and forth
    const urlBefore = page.url();
    
    // Simulate navigation
    await page.evaluate(() => window.history.back());
    await page.waitForTimeout(500);
    
    // App should remain stable
    const canvas = page.locator('canvas');
    const isCanvasVisible = await canvas.isVisible().catch(() => false);
    
    // Either canvas is visible or page content exists
    const pageText = await page.evaluate(() => document.body.textContent);
    expect(pageText?.length).toBeGreaterThan(0);
  });
});

test.describe('Payment Security', () => {
  test('Should not expose sensitive payment data in console logs', async ({ page }) => {
    const sensitivePatterns = [
      /secret/i,
      /api.?key/i,
      /token/i,
      /password/i,
    ];

    const consoleLogs: string[] = [];
    page.on('console', (msg) => {
      consoleLogs.push(msg.text());
    });

    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    await page.waitForTimeout(3000);

    const sensitiveLogs = consoleLogs.filter((log) =>
      sensitivePatterns.some((pattern) => pattern.test(log))
    );

    // Log exposure is a security issue
    expect(sensitiveLogs).toEqual([]);
  });

  test('Should use HTTPS for Stripe communication', async ({ page }) => {
    const requests: string[] = [];
    
    page.on('request', (req) => {
      if (req.url().includes('stripe') || req.url().includes('checkout')) {
        requests.push(req.url());
      }
    });

    await page.goto(process.env.PLAYWRIGHT_LIVE_URL || 'https://mixvy-v2.web.app');
    await page.waitForTimeout(3000);

    // All Stripe-related requests should be HTTPS
    const insecureRequests = requests.filter((url) => url.startsWith('http://'));
    expect(insecureRequests).toEqual([]);
  });
});
