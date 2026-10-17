import { expect, test } from '@playwright/test';
import {
  authenticateTestUser,
  enableFlutterSemantics,
  waitForAppReady,
} from './utils/auth';
import { loadTestCredentials } from './utils/credentials';
import { attachNetworkDiagnostics, simulateBackendLatency } from './utils/network';

const hasCredentials = loadTestCredentials();

test.describe.serial('MixVy resilience stress', () => {
  test.beforeEach(({ browserName }) => {
    test.skip(
      browserName !== 'chromium',
      'Flutter web semantic resilience interactions are validated in Chromium.',
    );
  });

  test('rejects malformed authentication input without submitting', async ({ page }) => {
    const authRequests: string[] = [];
    page.on('request', (request) => {
      if (request.url().includes('accounts:signInWithPassword')) {
        authRequests.push(request.url());
      }
    });

    await page.goto('/auth', { waitUntil: 'domcontentloaded' });
    await waitForAppReady(page);
    await enableFlutterSemantics(page);

    const email = page.getByRole('textbox', { name: 'Email address' });
    await email.click();
    await email.pressSequentially('not-an-email');
    await page.getByRole('button', { name: 'SIGN IN' }).click();

    await expect(page.getByText('Enter a valid email address').first()).toBeVisible();
    await expect(page.getByText('Enter your password').first()).toBeVisible();
    expect(authRequests).toEqual([]);
  });

  test('converges after rapid navigation and recovers from offline mode', async ({ page }, testInfo) => {
    test.skip(!hasCredentials, 'Run npm run test:e2e:provision-account first.');
    await page.setViewportSize({ width: 390, height: 844 });
    const diagnostics = await simulateBackendLatency(page, 250);

    try {
      expect(await authenticateTestUser(page)).toBe(true);
      await enableFlutterSemantics(page);

      for (let iteration = 0; iteration < 5; iteration += 1) {
        await page.getByRole('button', { name: 'Rooms', exact: true }).click();
        await page.getByRole('button', { name: 'Messages', exact: true }).click();
      }
      await expect(page).toHaveURL(/\/messages(?:$|[/?#])/);
      await expect(page.getByText('Inbox', { exact: true }).first()).toBeVisible();

      await page.context().setOffline(true);
      await page.getByRole('button', { name: 'Rooms', exact: true }).click();
      await expect(page.locator('body')).toBeVisible();
      await page.context().setOffline(false);

      await page.getByRole('button', { name: 'Messages', exact: true }).click();
      await expect(page.getByText('Inbox', { exact: true }).first()).toBeVisible();
      expect(diagnostics.pageErrors).toEqual([]);
    } finally {
      await page.context().setOffline(false);
      await attachNetworkDiagnostics(testInfo, diagnostics);
    }
  });

  test('surfaces recovery feedback when a live room loses connectivity', async ({ page }) => {
    test.skip(!hasCredentials, 'Run npm run test:e2e:provision-account first.');
    test.fail(
      true,
      'Browser offline mode does not deterministically sever the WebRTC transport.',
    );
    await page.setViewportSize({ width: 390, height: 844 });
    expect(await authenticateTestUser(page)).toBe(true);
    await enableFlutterSemantics(page);

    const enterRoom = page.getByRole('button', { name: 'Enter Room', exact: true });
    await expect(enterRoom).toBeVisible();
    await enterRoom.click();
    await expect(page).toHaveURL(/\/rooms\/room\//);

    const roomNotFound = page.getByText('Room not found', { exact: true });
    const activeRoomStatus = page.getByText(/Mic (?:ON|OFF)/).first();
    await expect(roomNotFound.or(activeRoomStatus)).toBeVisible();
    test.skip(
      await roomNotFound.isVisible(),
      'The discovery feed points to a deleted room; no active RTC fixture is available.',
    );

    await page.context().setOffline(true);
    try {
      await expect(
        page.getByText(/Reconnecting|Connection failed|Connection Lost/i).first(),
      ).toBeVisible({ timeout: 15000 });
    } finally {
      await page.context().setOffline(false);
    }
  });
});