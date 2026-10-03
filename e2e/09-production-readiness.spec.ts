import { expect, test } from '@playwright/test';
import {
  authenticateTestUser,
  enableFlutterSemantics,
  waitForAppReady,
} from './utils/auth';
import { loadTestCredentials } from './utils/credentials';

const hasCredentials = loadTestCredentials();

test.describe('MixVy production readiness', () => {
  test.describe.configure({ mode: process.env.CI ? 'parallel' : 'default' });
  test.setTimeout(150000);

  for (const viewport of [
    { name: 'desktop', width: 1440, height: 900 },
    { name: 'mobile', width: 390, height: 844 },
  ]) {
    test(`shows authentication actions on ${viewport.name}`, async ({ page }) => {
      await page.setViewportSize(viewport);
      await page.goto('/auth', { waitUntil: 'domcontentloaded' });
      await waitForAppReady(page);
      await enableFlutterSemantics(page);

      await expect(
        page.getByRole('button', { name: 'SIGN IN', exact: true }),
      ).toBeVisible();
      await expect(
        page.getByRole('button', { name: 'SIGN UP', exact: true }),
      ).toBeVisible();
      await expect(page.locator('body')).toBeVisible();
    });
  }

  test('exposes a guarded account deletion flow', async ({ page }) => {
    test.skip(!hasCredentials, 'A disposable E2E account is required.');
    expect(await authenticateTestUser(page)).toBe(true);
    await page.goto('/profile/account', { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);
    await enableFlutterSemantics(page);

    await expect(page.getByText('Account Center', { exact: true })).toBeVisible({
      timeout: 45000,
    });
    await page.getByRole('button', { name: 'Delete', exact: true }).click();
    await expect(page.getByText('Delete account?', { exact: true })).toBeVisible({
      timeout: 30000,
    });
    await expect(
      page.getByText('This action is permanent. Type DELETE to continue.'),
    ).toBeVisible();
    await page.getByRole('button', { name: 'Cancel', exact: true }).click();
    await expect(page.getByText('Delete account?', { exact: true })).toBeHidden();
  });

  test('redirects disabled payment offers', async ({ page }) => {
    test.skip(!hasCredentials, 'A disposable E2E account is required.');
    expect(await authenticateTestUser(page)).toBe(true);

    await page.goto('/profile/payments', { waitUntil: 'domcontentloaded' });
    await expect(page).not.toHaveURL(/\/payments(?:$|[/?#])/);
    await page.goto('/profile/vip', { waitUntil: 'domcontentloaded' });
    await expect(page).not.toHaveURL(/\/vip(?:$|[/?#])/);
  });
});