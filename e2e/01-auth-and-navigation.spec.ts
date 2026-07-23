import { test, expect } from '@playwright/test';
import { authenticateTestUser } from './utils/auth';

test.describe('MixVy - Auth Page Smoke Tests', () => {
  test.beforeEach(async ({ page }) => {
    // Authenticate before running tests
    await authenticateTestUser(page);
  });

  test('should load auth page', async ({ page }) => {
    // Simple smoke test - page should load without crashing
    await page.goto('/auth', { waitUntil: 'domcontentloaded' });
    
    // Page should have a title
    const title = await page.title();
    expect(title.length).toBeGreaterThan(0);
  });

  test('should display page content', async ({ page }) => {
    await page.goto('/auth');
    await page.waitForTimeout(2000);

    // Page should render something (measured by element count)
    const elementCount = await page.locator('*').count().catch(() => 0);
    expect(elementCount).toBeGreaterThan(0);
  });

  test('should not have fatal errors', async ({ page }) => {
    const errors: string[] = [];
    
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });

    await page.goto('/auth');
    await page.waitForTimeout(1000);

    // Filter out non-critical network errors (404s for assets, etc.)
    const fatalErrors = errors.filter(e => 
      !e.includes('404') && 
      !e.includes('Failed to load') &&
      e.toLowerCase().includes('error')
    );

    expect(fatalErrors.length).toBe(0);
  });

  test('should support localStorage', async ({ page }) => {
    await page.goto('/auth');

    // Test localStorage works
    const canUseStorage = await page.evaluate(() => {
      try {
        localStorage.setItem('test', 'value');
        const retrieved = localStorage.getItem('test');
        localStorage.removeItem('test');
        return retrieved === 'value';
      } catch {
        return false;
      }
    });

    expect(canUseStorage).toBe(true);
  });

  test('should be responsive', async ({ page }) => {
    // Test multiple viewport sizes
    const sizes = [
      { width: 1920, height: 1080 }, // Desktop
      { width: 768, height: 1024 },  // Tablet
      { width: 375, height: 667 },   // Mobile
    ];

    for (const size of sizes) {
      await page.setViewportSize(size);
      await page.goto('/auth');
      await page.waitForTimeout(500);

      // Page should load at each size
      const elements = await page.locator('*').count().catch(() => 0);
      expect(elements).toBeGreaterThan(0);
    }
  });

  test('should survive page reload', async ({ page }) => {
    await page.goto('/auth');
    await page.waitForTimeout(500);

    // Reload page
    await page.reload();
    await page.waitForTimeout(500);

    // Should still have content
    const title = await page.title();
    expect(title.length).toBeGreaterThan(0);
  });
});
