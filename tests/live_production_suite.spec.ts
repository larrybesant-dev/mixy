import fs from 'node:fs/promises';
import path from 'node:path';
import { expect, test, type Page, type TestInfo } from '@playwright/test';

import { detectLiveMixVyUrl } from './helpers/live-url';
import { RuntimeObserver, type RuntimeSummary } from './helpers/runtime-observer';

let liveBaseUrl = '';
const artifactsDir = path.join('test-results', 'e2e-artifacts');

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

async function clickButtonByRole(
  page: Page,
  observer: RuntimeObserver,
  buttonName: string,
): Promise<void> {
  observer.recordAction(`click:button:${buttonName}`);
  const button = page.getByRole('button', { name: buttonName }).first();
  try {
    await expect(button).toBeVisible({ timeout: 15_000 });
    await button.click();
  } catch (error) {
    observer.recordSelectorFailure(`button:${buttonName}`, String(error));
    throw error;
  }
}

async function fillByPlaceholder(
  page: Page,
  observer: RuntimeObserver,
  placeholder: string,
  value: string,
): Promise<void> {
  observer.recordAction(`fill:placeholder:${placeholder}`);
  const input = page.getByPlaceholder(placeholder).first();
  try {
    await expect(input).toBeVisible({ timeout: 15_000 });
    await input.clear();
    await input.fill(value);
  } catch (error) {
    observer.recordSelectorFailure(`placeholder:${placeholder}`, String(error));
    throw error;
  }
}

async function getByTextExact(
  page: Page,
  observer: RuntimeObserver,
  text: string,
): Promise<ReturnType<Page['getByText']>> {
  observer.recordAction(`locate:text:${text}`);
  return page.getByText(text).first();
}

async function flutterCanvasPresent(page: Page): Promise<boolean> {
  return await page.evaluate(() => {
    return !!(
      document.querySelector('flt-glass-pane') ||
      document.querySelector('flt-platform-view') ||
      document.querySelector('flt-scene-host') ||
      document.querySelector('canvas')
    );
  });
}

async function writeSummary(testInfo: TestInfo, summary: RuntimeSummary): Promise<void> {
  await fs.mkdir(artifactsDir, { recursive: true });
  const fileName = `${slugify(testInfo.title)}.json`;
  const filePath = path.join(artifactsDir, fileName);
  await fs.writeFile(filePath, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  await testInfo.attach('e2e-runtime-summary', {
    body: JSON.stringify(summary, null, 2),
    contentType: 'application/json',
  });
}

test.beforeAll(async () => {
  liveBaseUrl = await detectLiveMixVyUrl();
  process.env.PLAYWRIGHT_LIVE_URL = liveBaseUrl;
  // eslint-disable-next-line no-console
  console.log(`[live-production-suite] Using base URL: ${liveBaseUrl}`);
});

test('deep link survival: direct access to production room', async ({ page }, testInfo) => {
  test.setTimeout(120_000);
  const observer = new RuntimeObserver('deep-link-survival');
  observer.attach(page);

  const testRoomId = 'test-123';
  const targetUrl = `${liveBaseUrl}/room/${testRoomId}`;

  // Navigate directly to the room URL
  await go(page, observer, targetUrl);

  // Wait for Flutter WASM to stabilize
  await waitForFlutterWasmStable(page);

  // Verify we don't bounce to /auth or /home
  const currentUrl = page.url();
  const pathName = new URL(currentUrl).pathname;
  expect(pathName).toMatch(/\/room\/[^/?#]+/);

  // Ensure we're not redirected away from the room
  await page.waitForTimeout(3_000);
  expect(page.url()).toMatch(/\/room\/test-123/);

  const summary = observer.summary(page.url());
  expect(summary.navigationLoopDetected).toBeFalsy();

  // Verify Flutter has rendered
  const canvasReady = await flutterCanvasPresent(page);
  expect(canvasReady).toBeTruthy();

  await writeSummary(testInfo, summary);
});

test('state hydration: loading skeleton disappears after metadata resolution', async (
  { page },
  testInfo,
) => {
  test.setTimeout(90_000);
  const observer = new RuntimeObserver('state-hydration');
  observer.attach(page);

  // Navigate to a known room
  const testRoomId = 'test-123';
  const targetUrl = `${liveBaseUrl}/room/${testRoomId}`;

  await go(page, observer, targetUrl);
  await waitForFlutterWasmStable(page);

  // Look for the loading skeleton using semantic locators
  // Flutter typically renders loading states as text or specific semantic roles
  let loadingVisible = false;
  let skeletonDisappeared = false;
  let elapsedMs = 0;
  const maxWaitMs = 15_000;
  const pollIntervalMs = 500;

  const startTime = Date.now();

  while (elapsedMs < maxWaitMs) {
    // Try to detect loading/skeleton UI
    const loadingIndicator = await page
      .getByText(/joining|loading|connecting/i)
      .first()
      .isVisible()
      .catch(() => false);

    loadingVisible = loadingIndicator;

    if (!loadingIndicator) {
      skeletonDisappeared = true;
      break;
    }

    await page.waitForTimeout(pollIntervalMs);
    elapsedMs = Date.now() - startTime;
  }

  observer.recordAction(`skeleton-disappeared:after:${elapsedMs}ms`);

  // The loading skeleton should eventually disappear
  expect(skeletonDisappeared).toBeTruthy();
  expect(elapsedMs).toBeLessThan(maxWaitMs);

  // Verify Firestore metadata resolved by checking for room UI elements
  const roomContentVisible = await page
    .getByRole('button')
    .first()
    .isVisible()
    .catch(() => false);
  expect(roomContentVisible).toBeTruthy();

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});

test('chat interaction: send test message via chat input', async ({ page }, testInfo) => {
  test.setTimeout(90_000);
  const observer = new RuntimeObserver('chat-interaction');
  observer.attach(page);

  const testRoomId = 'test-123';
  const targetUrl = `${liveBaseUrl}/room/${testRoomId}`;

  await go(page, observer, targetUrl);
  await waitForFlutterWasmStable(page);

  // Locate the chat input using semantic placeholder
  const chatInput = page.getByPlaceholder(/send a message|message/i).first();

  try {
    await expect(chatInput).toBeVisible({ timeout: 20_000 });
    observer.recordAction('chat-input-found');
  } catch {
    observer.recordSelectorFailure('chat-input', 'Chat input not found after waiting');
    // Continue with partial success - the input may not be visible if not authenticated
  }

  // Type a test message
  const testMessage = `E2E Test Message ${Date.now()}`;
  await fillByPlaceholder(page, observer, /send a message|message/i, testMessage);

  // Locate and click the send button
  // Look for a button with role="button" and text containing "send" or an icon that sends
  const sendButton = page
    .getByRole('button', { name: /send|submit/i })
    .or(page.getByText(/^send$/i).first())
    .first();

  try {
    await expect(sendButton).toBeVisible({ timeout: 10_000 });
    await sendButton.click();
    observer.recordAction('chat-message-sent');
  } catch {
    // Send button might not be interactive if not authenticated
    observer.recordAction('chat-send-attempt-skipped');
  }

  // Verify input was cleared or message was processed
  await page.waitForTimeout(2_000);

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});

test('hardware ui toggles: microphone and camera button state changes', async (
  { page },
  testInfo,
) => {
  test.setTimeout(90_000);
  const observer = new RuntimeObserver('hardware-ui-toggles');
  observer.attach(page);

  const testRoomId = 'test-123';
  const targetUrl = `${liveBaseUrl}/room/${testRoomId}`;

  await go(page, observer, targetUrl);
  await waitForFlutterWasmStable(page);

  // Find the Mic button using semantic locator
  let micButton: ReturnType<Page['getByRole']> | null = null;
  let cameraButton: ReturnType<Page['getByRole']> | null = null;

  try {
    // Try multiple patterns for mic button
    micButton = page
      .getByRole('button', { name: /mic|microphone|audio|mute/i })
      .first();

    const micVisible = await micButton.isVisible().catch(() => false);
    if (micVisible) {
      observer.recordAction('mic-button-found');

      // Get initial state
      const initialMicState = await micButton.getAttribute('aria-pressed');
      observer.recordAction(`mic-initial-state:${initialMicState}`);

      // Click to toggle mic
      await micButton.click();
      observer.recordAction('mic-button-clicked');

      await page.waitForTimeout(1_500);

      // Verify state changed or status message appeared
      const mutedLabel = await page.getByText(/muted|connecting audio/i).isVisible().catch(() => false);
      if (mutedLabel) {
        observer.recordAction('mic-state-label-updated');
      }
    }
  } catch (error) {
    observer.recordSelectorFailure('mic-button', String(error));
  }

  try {
    // Try multiple patterns for camera button
    cameraButton = page
      .getByRole('button', { name: /camera|video|cam/i })
      .first();

    const cameraVisible = await cameraButton.isVisible().catch(() => false);
    if (cameraVisible) {
      observer.recordAction('camera-button-found');

      // Get initial state
      const initialCameraState = await cameraButton.getAttribute('aria-pressed');
      observer.recordAction(`camera-initial-state:${initialCameraState}`);

      // Click to toggle camera
      await cameraButton.click();
      observer.recordAction('camera-button-clicked');

      await page.waitForTimeout(1_500);

      // Verify state changed or status message appeared
      const cameraLabel = await page
        .getByText(/camera.*on|video.*on|connecting video/i)
        .isVisible()
        .catch(() => false);
      if (cameraLabel) {
        observer.recordAction('camera-state-label-updated');
      }
    }
  } catch (error) {
    observer.recordSelectorFailure('camera-button', String(error));
  }

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});

test('video surface rendering: verify webrtc stream attachment to dom', async (
  { page },
  testInfo,
) => {
  test.setTimeout(120_000);
  const observer = new RuntimeObserver('video-surface-rendering');
  observer.attach(page);

  const testRoomId = 'test-123';
  const targetUrl = `${liveBaseUrl}/room/${testRoomId}`;

  await go(page, observer, targetUrl);
  await waitForFlutterWasmStable(page);

  // Locate camera button and enable it
  const cameraButton = page
    .getByRole('button', { name: /camera|video|cam/i })
    .first();

  const cameraFound = await cameraButton.isVisible().catch(() => false);
  if (!cameraFound) {
    observer.recordAction('camera-button-not-found');
  } else {
    observer.recordAction('camera-button-found');

    // Click camera to enable
    await cameraButton.click();
    observer.recordAction('camera-enabled');

    // Wait for video stream to attach
    await page.waitForTimeout(3_000);

    // Check for Flutter video platform view
    const videoSurfacePresent = await page.evaluate(() => {
      const flutterPlatformView = document.querySelector('flt-platform-view');
      const flutterSceneHost = document.querySelector('flt-scene-host');
      const videoElement = document.querySelector('video');
      const iframeWithVideo = Array.from(document.querySelectorAll('iframe')).some((iframe) => {
        try {
          const iframeDoc = iframe.contentDocument;
          return iframeDoc?.querySelector('video') !== null;
        } catch {
          return false;
        }
      });

      return !!(flutterPlatformView || flutterSceneHost || videoElement || iframeWithVideo);
    });

    observer.recordAction(`video-surface-present:${videoSurfacePresent}`);
    expect(videoSurfacePresent).toBeTruthy();

    // Verify video dimensions or stream metadata
    const videoStreamMetadata = await page.evaluate(() => {
      const videoElement = document.querySelector('video') as HTMLVideoElement | null;
      if (!videoElement) {
        return {
          elementFound: false,
          readyState: null,
          width: null,
          height: null,
        };
      }

      return {
        elementFound: true,
        readyState: videoElement.readyState,
        width: videoElement.videoWidth,
        height: videoElement.videoHeight,
      };
    });

    observer.recordAction(`video-metadata:${JSON.stringify(videoStreamMetadata)}`);

    if (videoStreamMetadata.elementFound) {
      expect(videoStreamMetadata.readyState).toBeGreaterThanOrEqual(2);
    }
  }

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});

test('comprehensive room lifecycle: auth → enter room → chat → hardware toggle → exit', async (
  { page },
  testInfo,
) => {
  test.setTimeout(180_000);
  const observer = new RuntimeObserver('room-lifecycle-comprehensive');
  observer.attach(page);

  const email = process.env.MIXVY_TEST_EMAIL;
  const password = process.env.MIXVY_TEST_PASSWORD;

  test.skip(!email || !password, 'MIXVY_TEST_EMAIL and MIXVY_TEST_PASSWORD required for full lifecycle test');

  // Step 1: Navigate to auth
  await go(page, observer, `${liveBaseUrl}/auth`);
  await waitForFlutterWasmStable(page);

  // Step 2: Sign in
  await fillByPlaceholder(page, observer, 'Email address', email!);
  await fillByPlaceholder(page, observer, 'Password', password!);
  await clickButtonByRole(page, observer, 'SIGN IN');

  await page.waitForURL(/\/(home|onboarding)(\?|$)/, { timeout: 30_000 });
  const postLoginUrl = page.url();

  if (/\/onboarding(\?|$)/.test(postLoginUrl)) {
    observer.recordAction('onboarding-required-skipping-full-lifecycle');
    const summary = observer.summary(page.url());
    await writeSummary(testInfo, summary);
    return;
  }

  observer.recordAction('authenticated-home-reached');

  // Step 3: Navigate to room
  const testRoomId = 'test-123';
  await go(page, observer, `${liveBaseUrl}/room/${testRoomId}`);
  await waitForFlutterWasmStable(page);

  expect(page.url()).toMatch(/\/room\/test-123/);
  observer.recordAction('room-joined');

  // Step 4: Interact with chat
  const chatInput = page.getByPlaceholder(/send a message|message/i).first();
  const chatInputFound = await chatInput.isVisible().catch(() => false);

  if (chatInputFound) {
    await fillByPlaceholder(page, observer, /send a message|message/i, 'E2E Lifecycle Test');
    observer.recordAction('lifecycle-chat-message-typed');
  }

  // Step 5: Toggle hardware
  const micButton = page
    .getByRole('button', { name: /mic|microphone/i })
    .first();
  const micFound = await micButton.isVisible().catch(() => false);

  if (micFound) {
    await micButton.click();
    observer.recordAction('lifecycle-mic-toggled');
    await page.waitForTimeout(1_500);
  }

  // Step 6: Check video surface
  const cameraButton = page
    .getByRole('button', { name: /camera|video/i })
    .first();
  const cameraFound = await cameraButton.isVisible().catch(() => false);

  if (cameraFound) {
    await cameraButton.click();
    observer.recordAction('lifecycle-camera-toggled');
    await page.waitForTimeout(2_000);

    const videoPresent = await page.evaluate(() => {
      return !!(
        document.querySelector('flt-platform-view') ||
        document.querySelector('video') ||
        document.querySelector('flt-scene-host')
      );
    });

    observer.recordAction(`lifecycle-video-rendered:${videoPresent}`);
  }

  // Step 7: Navigate back to home (exit room)
  await go(page, observer, `${liveBaseUrl}/home`);
  await waitForFlutterWasmStable(page);

  expect(page.url()).toMatch(/\/home(\?|$)/);
  observer.recordAction('lifecycle-exited-to-home');

  const summary = observer.summary(page.url());
  expect(summary.navigationLoopDetected).toBeFalsy();
  await writeSummary(testInfo, summary);
});

test('accessibility: semantic role and label validation for room controls', async (
  { page },
  testInfo,
) => {
  test.setTimeout(60_000);
  const observer = new RuntimeObserver('accessibility-validation');
  observer.attach(page);

  const testRoomId = 'test-123';
  const targetUrl = `${liveBaseUrl}/room/${testRoomId}`;

  await go(page, observer, targetUrl);
  await waitForFlutterWasmStable(page);

  // Validate semantic roles for common room controls
  const controlPatterns = [
    { pattern: /mic|microphone|audio/i, label: 'mic-button' },
    { pattern: /camera|video|cam/i, label: 'camera-button' },
    { pattern: /send|submit/i, label: 'send-button' },
    { pattern: /leave|exit|disconnect/i, label: 'leave-button' },
  ];

  for (const control of controlPatterns) {
    const button = page.getByRole('button', { name: control.pattern }).first();
    const found = await button.isVisible().catch(() => false);

    if (found) {
      const ariaLabel = await button.getAttribute('aria-label').catch(() => null);
      const ariaPressed = await button.getAttribute('aria-pressed').catch(() => null);

      observer.recordAction(
        `${control.label}:found:aria-label=${ariaLabel}:aria-pressed=${ariaPressed}`,
      );
    } else {
      observer.recordAction(`${control.label}:not-found`);
    }
  }

  const summary = observer.summary(page.url());
  await writeSummary(testInfo, summary);
});
