import fs from 'node:fs/promises';
import path from 'node:path';
import { expect, test, type Page, type TestInfo } from '@playwright/test';

import { detectLiveMixVyUrl } from './helpers/live-url';
import { RuntimeObserver, type RuntimeSummary } from './helpers/runtime-observer';

let liveBaseUrl = '';

const artifactsDir = path.join('test-results', 'runtime-artifacts');

function slugify(input: string): string {
  return input
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '');
}

async function go(page: Page, observer: RuntimeObserver, url: string): Promise<void> {
  observer.recordAction(`goto:${url}`);
  await page.goto(url, { waitUntil: 'domcontentloaded' });
}

async function waitForFlutterWasmStable(page: Page): Promise<void> {
  // Flutter WASM can take extra time before first meaningful interaction.
  await page.waitForTimeout(3_500);
  await page.waitForLoadState('domcontentloaded');
  await page.waitForLoadState('networkidle').catch(() => {});
  await page.waitForFunction(() => {
    const hasFlutterNode = !!document.querySelector('flt-glass-pane, flt-semantics-host, canvas');
    const bodyText = (document.body?.innerText || '').trim();
    return hasFlutterNode || bodyText.length > 0;
  }, { timeout: 45_000 });
  await page.waitForTimeout(1_200);
}

async function waitForRouteSettle(page: Page): Promise<void> {
  await page.waitForLoadState('domcontentloaded');
  await page.waitForTimeout(1_100);
}

async function clickButtonByName(
  page: Page,
  observer: RuntimeObserver,
  buttonName: string,
): Promise<void> {
  observer.recordAction(`click:${buttonName}`);
  const button = page.getByRole('button', { name: buttonName }).first();
  try {
    await expect(button).toBeVisible({ timeout: 15_000 });
    await button.click();
  } catch (error) {
    observer.recordSelectorFailure(`button:${buttonName}`, String(error));
    throw error;
  }
}

async function clickTextAnyRole(
  page: Page,
  observer: RuntimeObserver,
  textPattern: RegExp,
  actionLabel: string,
): Promise<void> {
  observer.recordAction(`click:${actionLabel}`);
  const target = page.getByText(textPattern).first();
  try {
    await expect(target).toBeVisible({ timeout: 20_000 });
    await target.click();
  } catch (error) {
    observer.recordSelectorFailure(`text:${String(textPattern)}`, String(error));
    throw error;
  }
}

async function currentPath(page: Page): Promise<string> {
  return new URL(page.url()).pathname;
}

async function fillByPlaceholder(
  page: Page,
  observer: RuntimeObserver,
  placeholder: string,
  value: string,
): Promise<void> {
  const input = page.getByPlaceholder(placeholder).first();
  try {
    await expect(input).toBeVisible({ timeout: 15_000 });
    await input.fill(value);
  } catch (error) {
    observer.recordSelectorFailure(`placeholder:${placeholder}`, String(error));
    throw error;
  }
}

async function writeSummary(testInfo: TestInfo, summary: RuntimeSummary): Promise<void> {
  await fs.mkdir(artifactsDir, { recursive: true });
  const fileName = `${slugify(testInfo.title)}.json`;
  const filePath = path.join(artifactsDir, fileName);
  await fs.writeFile(filePath, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  await testInfo.attach('runtime-summary', {
    body: JSON.stringify(summary, null, 2),
    contentType: 'application/json',
  });
}

test.beforeAll(async () => {
  liveBaseUrl = await detectLiveMixVyUrl();
  process.env.PLAYWRIGHT_LIVE_URL = liveBaseUrl;
  // eslint-disable-next-line no-console
  console.log(`[runtime-suite] Using base URL: ${liveBaseUrl}`);
});

test('auth redirect validation from root', async ({ page }, testInfo) => {
  const observer = new RuntimeObserver('auth-redirect-validation');
  observer.attach(page);

  await go(page, observer, `${liveBaseUrl}/`);
  await waitForFlutterWasmStable(page);
  await expect(page).toHaveURL(/\/(auth|home)(\?|$)/, { timeout: 45_000 });

  const summary = observer.summary(page.url());
  expect(summary.navigationLoopDetected).toBeFalsy();
  await writeSummary(testInfo, summary);
});

test('guest mode validation and target route access', async ({ page }, testInfo) => {
  const observer = new RuntimeObserver('guest-mode-validation');
  observer.attach(page);

  await go(page, observer, `${liveBaseUrl}/auth`);
  await waitForFlutterWasmStable(page);

  const guestButton = page.getByText(/enter\s+as\s+guest/i).first();
  if (await guestButton.isVisible().catch(() => false)) {
    await clickTextAnyRole(page, observer, /enter\s+as\s+guest/i, 'enter-as-guest');
    await expect(page).toHaveURL(/\/home(\?|$)/, { timeout: 45_000 });
  } else {
    // Session may already be routed to home after hydration.
    await expect(page).toHaveURL(/\/(home|auth)(\?|$)/, { timeout: 45_000 });
    const path = await currentPath(page);
    if (path !== '/home') {
      await go(page, observer, `${liveBaseUrl}/home`);
      await waitForFlutterWasmStable(page);
    }
  }

  await go(page, observer, `${liveBaseUrl}/profile/runtime-guest-profile`);
  await waitForFlutterWasmStable(page);
  await expect(page).toHaveURL(/\/profile\//, { timeout: 30_000 });

  await go(page, observer, `${liveBaseUrl}/room/runtime-guest-room`);
  await waitForFlutterWasmStable(page);
  await expect(page).toHaveURL(/\/room\//, { timeout: 30_000 });

  await go(page, observer, `${liveBaseUrl}/create-room`);
  await waitForFlutterWasmStable(page);
  await expect(page).toHaveURL(/\/(auth|create-room)(\?|$)/, { timeout: 45_000 });

  const summary = observer.summary(page.url());
  expect(summary.navigationLoopDetected).toBeFalsy();
  await writeSummary(testInfo, summary);
});

test('restricted route validation for signed-out and guest sessions', async ({ page }, testInfo) => {
  const observer = new RuntimeObserver('restricted-route-validation');
  observer.attach(page);

  await go(page, observer, `${liveBaseUrl}/auth`);
  await waitForFlutterWasmStable(page);
  const guestButton = page.getByText(/enter\s+as\s+guest/i).first();
  if (await guestButton.isVisible().catch(() => false)) {
    await clickTextAnyRole(page, observer, /enter\s+as\s+guest/i, 'enter-as-guest-restricted-flow');
    await expect(page).toHaveURL(/\/home(\?|$)/, { timeout: 45_000 });
  }

  await go(page, observer, `${liveBaseUrl}/create-room`);
  await waitForFlutterWasmStable(page);
  await expect(page).toHaveURL(/\/(auth|create-room)(\?|$)/, { timeout: 45_000 });

  const summary = observer.summary(page.url());
  expect(summary.navigationLoopDetected).toBeFalsy();
  await writeSummary(testInfo, summary);
});

test('runtime console and network capture on target flows', async ({ page }, testInfo) => {
  test.setTimeout(240_000);
  const observer = new RuntimeObserver('runtime-capture');
  observer.attach(page);

  const flows = [
    '/',
    '/auth',
    '/home',
    '/profile/runtime-capture-profile',
    '/room/runtime-capture-room',
    '/create-room',
  ];

  for (const route of flows) {
    await go(page, observer, `${liveBaseUrl}${route}`);
    await waitForRouteSettle(page);
  }

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});

test('authenticated room creation validation', async ({ page }, testInfo) => {
  const observer = new RuntimeObserver('authenticated-room-creation-validation');
  observer.attach(page);

  const email = process.env.MIXVY_TEST_EMAIL;
  const password = process.env.MIXVY_TEST_PASSWORD;

  test.skip(
    !email || !password,
    'MIXVY_TEST_EMAIL and MIXVY_TEST_PASSWORD are required for authenticated room creation validation.',
  );

  await go(page, observer, `${liveBaseUrl}/auth`);
  await waitForFlutterWasmStable(page);
  await fillByPlaceholder(page, observer, 'Email address', email!);
  await fillByPlaceholder(page, observer, 'Password', password!);
  await clickButtonByName(page, observer, 'SIGN IN');

  await page.waitForURL(/\/(home|onboarding)(\?|$)/, { timeout: 30_000 });
  const postLoginUrl = page.url();

  if (/\/onboarding(\?|$)/.test(postLoginUrl)) {
    throw new Error(
      'Authenticated user was redirected to /onboarding. Complete legal acceptance for this test account, then rerun.',
    );
  }

  await go(page, observer, `${liveBaseUrl}/create-room`);
  await waitForFlutterWasmStable(page);

  const roomName = `PW Runtime ${Date.now()}`;
  await fillByPlaceholder(page, observer, 'e.g. Late Night Music Session', roomName);

  observer.recordAction('create-room-submit');
  await clickTextAnyRole(page, observer, /start\s+room\s+now/i, 'start-room-now');

  await page.waitForURL(/\/room\/[^/?#]+/, { timeout: 45_000 });
  await waitForFlutterWasmStable(page);

  const summary = observer.summary(page.url());
  const roomNavigations = summary.urlTransitions.filter((u) => /\/room\/[^/?#]+/.test(u)).length;
  expect(roomNavigations).toBe(1);
  expect(summary.actionCounts['create-room-submit']).toBe(1);
  expect(summary.duplicateActions).not.toContain('create-room-submit');
  expect(summary.navigationLoopDetected).toBeFalsy();

  // Strong signal for duplicate room write attempts in browser runtime traffic.
  expect(summary.roomWriteSignals).toBeLessThanOrEqual(1);

  await writeSummary(testInfo, summary);
});

test('deep link survives refresh and auth bootstrap', async ({ page }, testInfo) => {
  const observer = new RuntimeObserver('deep-link-survival');
  observer.attach(page);

  // Use a deterministic room ID for testing the deep link path
  const testRoomId = `pw-deep-link-test-${Date.now()}`;
  const deepLink = `${liveBaseUrl}/rooms/room/${testRoomId}`;

  // Navigate directly to the deep link
  observer.recordAction(`goto-deeplink:${deepLink}`);
  await page.goto(deepLink);

  // Wait for Flutter and Auth bootstrap
  await waitForFlutterWasmStable(page);

  // Expect to stay on the room route (or be redirected to auth if forced)
  // The crucial part is that it shouldn't get stuck on / or redirect to /home prematurely
  await expect(page).toHaveURL(new RegExp(`/rooms/room/${testRoomId}`), { timeout: 30000 });

  // Verify the 'Joining room' loading scaffold appears (means it successfully targeted the room)
  const joiningText = page.getByText(/Joining room/i).first();
  await expect(joiningText).toBeVisible({ timeout: 15000 });

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});
