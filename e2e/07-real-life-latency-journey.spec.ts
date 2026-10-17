import { expect, test } from '@playwright/test';
import {
  authenticateTestUser,
  enableFlutterSemantics,
  waitForAppReady,
} from './utils/auth';
import { loadTestCredentials } from './utils/credentials';
import {
  attachNetworkDiagnostics,
  simulateBackendLatency,
} from './utils/network';

const hasCredentials = loadTestCredentials();

test.describe('MixVy real-life journey under latency', () => {
  test('signs in and explores live rooms and messaging', async ({ page, browserName }, testInfo) => {
    test.skip(browserName !== 'chromium', 'Flutter web semantic interactions are validated in Chromium.');
    test.skip(
      !hasCredentials,
      'Set TEST_EMAIL and TEST_PASSWORD or run npm run test:e2e:provision-account.',
    );

    await page.setViewportSize({ width: 390, height: 844 });
    const diagnostics = await simulateBackendLatency(page);

    try {
      const authenticated = await authenticateTestUser(page);
      expect(authenticated, 'Expected the configured test account to sign in through the UI').toBe(true);
      await waitForAppReady(page);
      await enableFlutterSemantics(page);
      await expect(page).not.toHaveURL(/\/auth(?:$|[/?#])/);

      await page.getByRole('button', { name: 'Rooms', exact: true }).click();
      await expect(page).toHaveURL(/\/(?:rooms|\?__dl=%2Frooms)/);
      await expect(page.getByText('Rooms', { exact: true }).first()).toBeVisible();

      const musicCategory = page.getByRole('button', { name: /Music$/ }).first();
      await expect(musicCategory).toBeVisible();
      await musicCategory.click();

      await page.getByRole('button', { name: 'Messages', exact: true }).click();
      await expect(page).toHaveURL(/\/messages(?:$|[/?#])/);
      await expect(page.getByText('Inbox', { exact: true }).first()).toBeVisible();

      const newMessageButton = page.getByRole('button', { name: 'New message', exact: true }).first();
      await expect(newMessageButton).toBeVisible();
      await newMessageButton.click();
      await expect(page).toHaveURL(/\/messages\/new(?:$|[/?#])/);

      const peopleSearch = page.locator(
        'input[aria-label*="Search people" i], input[placeholder*="Search people" i]',
      ).first();
      await expect(peopleSearch).toBeVisible();
      await peopleSearch.click();
      await peopleSearch.pressSequentially('slow network test', { delay: 35 });
      await expect(peopleSearch).toHaveValue('slow network test');

      expect(
        diagnostics.delayedRequests.length,
        'Expected at least one Firebase or Google API request to be latency-shaped',
      ).toBeGreaterThan(0);
      expect(diagnostics.pageErrors, 'Expected no uncaught browser runtime errors').toEqual([]);
    } finally {
      await attachNetworkDiagnostics(testInfo, diagnostics);
    }
  });
});