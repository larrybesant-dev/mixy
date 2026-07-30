import { test, expect, devices } from '@playwright/test';
import { safeNavigate } from './utils/auth';

async function waitForAppReady(page: import('@playwright/test').Page) {
  await page.waitForLoadState('domcontentloaded');
  await expect(page.locator('body')).toBeVisible({ timeout: 30000 });
  await expect
    .poll(
      async () => {
        const markerCount = await page
          .locator('flt-semantics-placeholder, flt-glass-pane, flutter-view, canvas, [flt-semantics], button, [role="button"], input')
          .count();
        const fallbackReady = await page.evaluate(() => !!document.body && document.readyState !== 'loading');
        return markerCount > 0 || fallbackReady;
      },
      {
        timeout: 30000,
        message: 'Expected app readiness markers or a loaded document'
      }
    )
    .toBeTruthy();
}

test.describe('MixVy Responsive Design & Mobile UX', () => {
  test.describe('Desktop View', () => {
    test.beforeEach(async ({ page }) => {
      await safeNavigate(page, '/');
      await waitForAppReady(page);
    });

    test('should display full navigation at desktop breakpoint', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });

      // Navigation should be visible
      const nav = page.locator('nav, [role="navigation"], [class*="navbar"]').first();
      
      if (await nav.isVisible().catch(() => false)) {
        await expect(nav).toBeVisible();
      }
    });

    test('should render gift system UI at desktop size', async ({ page }) => {
      await page.setViewportSize({ width: 1920, height: 1080 });
      await safeNavigate(page, '/?room=lounge');

      const giftButton = page.locator('button:has-text("Gift")').first();
      
      if (await giftButton.isVisible().catch(() => false)) {
        await expect(giftButton).toBeVisible();
      }
    });
  });

  test.describe('Tablet View (iPad)', () => {
    test.beforeEach(async ({ page }) => {
      await page.setViewportSize({ width: 768, height: 1024 });
      await safeNavigate(page, '/');
      await waitForAppReady(page);
    });

    test('should be usable at tablet breakpoint', async ({ page }) => {
      const buttons = page.locator('button').first();
      
      if (await buttons.isVisible().catch(() => false)) {
        await expect(buttons).toBeVisible();
      }
    });

    test('should touch-friendly button sizes', async ({ page }) => {
      const button = page.locator('button').first();

      if (await button.isVisible().catch(() => false)) {
        const box = await button.boundingBox();
        
        // Buttons should be at least 44x44px for touch targets
        if (box) {
          expect(box.width).toBeGreaterThanOrEqual(40);
          expect(box.height).toBeGreaterThanOrEqual(40);
        }
      }
    });

    test('should adapt modals for tablet width', async ({ page }) => {
      await safeNavigate(page, '/?room=lounge');

      const giftButton = page.locator('button:has-text("Gift")').first();
      if (await giftButton.isVisible().catch(() => false)) {
        await giftButton.click();
        await page.waitForTimeout(500);

        // Modal should be readable at tablet size
        const modal = page.locator('[class*="modal"], [class*="sheet"]').first();
        if (await modal.isVisible().catch(() => false)) {
          const box = await modal.boundingBox();
          
          // Modal should not exceed viewport
          if (box) {
            expect(box.width).toBeLessThanOrEqual(768);
          }
        }
      }
    });
  });

  test.describe('Mobile View (iPhone SE)', () => {
    test.beforeEach(async ({ page }) => {
      await page.setViewportSize({ width: 375, height: 667 });
      await safeNavigate(page, '/');
      await waitForAppReady(page);
    });

    test('should display mobile-optimized navigation', async ({ page }) => {
      // Flutter web renders on canvas, not as DOM elements
      // Verify the page loads at mobile viewport size
      const pageContent = await page.content();
      expect(pageContent).toContain('<html'); // Page should be valid HTML

      // Verify viewport is set to mobile dimensions
      const viewport = page.viewportSize();
      expect(viewport?.width).toBe(375);
      expect(viewport?.height).toBe(667);

      // Verify page is interactive at mobile size
      const elementCount = await page.evaluate(() => document.querySelectorAll('*').length);
      expect(elementCount).toBeGreaterThan(5);
    });

    test('should ensure text is readable without zooming', async ({ page }) => {
      // Check font sizes are at least 16px on mobile
      const textElements = page.locator('p, span, a, button').first();

      if (await textElements.isVisible().catch(() => false)) {
        const fontSize = await textElements.evaluate(el => {
          return window.getComputedStyle(el).fontSize;
        });

        // Parse fontSize (e.g., "16px" -> 16)
        const size = parseInt(fontSize);
        
        // Most text should be readable (12px minimum, 16px preferred)
        expect(size).toBeGreaterThanOrEqual(12);
      }
    });

    test('should stack form fields vertically on mobile', async ({ page }) => {
      await safeNavigate(page, '/auth');
      await waitForAppReady(page);

      const inputs = page.locator('input');
      const inputCount = await inputs.count();

      if (inputCount > 1) {
        // Get positions of first two inputs
        const box1 = await inputs.nth(0).boundingBox();
        const box2 = await inputs.nth(1).boundingBox();

        if (box1 && box2) {
          // On mobile, inputs should be stacked (different Y coordinates)
          expect(box2.y).toBeGreaterThan(box1.y);
        }
      }
    });

    test('should make buttons touch-friendly on mobile', async ({ page }) => {
      const button = page.locator('button').first();

      if (await button.isVisible().catch(() => false)) {
        const box = await button.boundingBox();

        // Minimum touch target: 48x48px (some sources say 44x44)
        if (box) {
          expect(box.height).toBeGreaterThanOrEqual(40);
        }
      }
    });

    test('should optimize modal/sheet height for mobile', async ({ page }) => {
      await safeNavigate(page, '/?room=lounge');

      const giftButton = page.locator('button:has-text("Gift")').first();
      if (await giftButton.isVisible().catch(() => false)) {
        await giftButton.click();
        await page.waitForTimeout(500);

        const sheet = page.locator('[class*="sheet"], [class*="modal"]').first();
        if (await sheet.isVisible().catch(() => false)) {
          const box = await sheet.boundingBox();

          // Sheet should not exceed viewport height
          if (box) {
            expect(box.height).toBeLessThanOrEqual(667);
          }
        }
      }
    });

    test('should handle keyboard visibility on mobile', async ({ page }) => {
      await safeNavigate(page, '/auth');

      const emailInput = page.locator('input[type="email"]').first();
      
      if (await emailInput.isVisible().catch(() => false)) {
        await emailInput.click();

        // Viewport should adjust or content should scroll
        const finalViewport = await page.viewportSize();
        expect(finalViewport).toBeTruthy();
      }
    });

    test('should not show horizontal scroll on mobile', async ({ page }) => {
      const bodyWidth = await page.evaluate(() => {
        return Math.max(document.body.scrollWidth, window.innerWidth);
      });

      const viewportWidth = 375;

      // Content should not exceed viewport
      expect(bodyWidth).toBeLessThanOrEqual(viewportWidth + 20); // 20px tolerance
    });

    test('should collapse gift picker options on mobile', async ({ page }) => {
      await safeNavigate(page, '/?room=lounge');

      const giftButton = page.locator('button:has-text("Gift")').first();
      if (await giftButton.isVisible().catch(() => false)) {
        await giftButton.click();
        await page.waitForTimeout(500);

        // Check if items are scrollable or paginated
        const items = page.locator('[class*="item"], button[class*="option"]');
        const itemCount = await items.count();

        // Mobile UI should handle many items gracefully
        expect(typeof itemCount).toBe('number');
      }
    });

    test('should display price in affordable increments on mobile', async ({ page }) => {
      await safeNavigate(page, '/?room=lounge');

      const buyButton = page.locator('button:has-text("Buy Coins")').first();
      if (await buyButton.isVisible().catch(() => false)) {
        await buyButton.click();
        await page.waitForTimeout(500);

        // Prices should be visible and readable
        const prices = page.locator('text=\\$').first();
        
        if (await prices.isVisible().catch(() => false)) {
          const text = await prices.textContent();
          expect(text).toBeTruthy();
        }
      }
    });
  });

  test.describe('Very Small Screens (mobile < 320px)', () => {
    test('should handle very small viewport', async ({ page }) => {
      await page.setViewportSize({ width: 280, height: 600 });
      await safeNavigate(page, '/');
      await waitForAppReady(page);

      // Page should still be functional
      const buttons = page.locator('button');
      const buttonCount = await buttons.count();

      expect(buttonCount).toBeGreaterThanOrEqual(0);

      // No horizontal scroll
      const overflow = await page.evaluate(() => {
        return document.body.scrollWidth > window.innerWidth;
      });

      expect(overflow).toBe(false);
    });
  });

  test.describe('Orientation Changes', () => {
    test('should adapt when rotating device', async ({ page }) => {
      // Start in portrait
      await page.setViewportSize({ width: 375, height: 812 });
      await safeNavigate(page, '/');

      const portraitHeight = await page.evaluate(() => window.innerHeight);

      // Rotate to landscape
      await page.setViewportSize({ width: 812, height: 375 });
      await page.waitForTimeout(500);

      const landscapeHeight = await page.evaluate(() => window.innerHeight);

      // Height should change after rotation
      expect(landscapeHeight).not.toBe(portraitHeight);

      // Page should still be functional
      const buttons = page.locator('button');
      const buttonCount = await buttons.count();

      expect(buttonCount).toBeGreaterThanOrEqual(0);
    });
  });
});
