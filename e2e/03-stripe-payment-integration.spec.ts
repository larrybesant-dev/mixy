import { expect, Page, test } from '@playwright/test';
import {
  authenticateTestUser,
  enableFlutterSemantics,
  safeNavigate,
} from './utils/auth';
import { loadTestCredentials } from './utils/credentials';

const hasCredentials = loadTestCredentials();
const paymentsEnabled = process.env.E2E_PAYMENTS_ENABLED === 'true';
const checkoutFunctionPattern = '**/createCheckoutSessionCallable**';
const checkoutUrl = 'https://checkout.stripe.com/c/pay/mixvy-e2e-session';

async function openPayments(page: Page): Promise<void> {
  expect(await authenticateTestUser(page)).toBe(true);
  await safeNavigate(page, '/profile/payments');
  await enableFlutterSemantics(page);
  await expect(page.getByText('MixVy Premium', { exact: true })).toBeVisible();
}

function upgradeButton(page: Page) {
  return page.getByRole('button', { name: /Upgrade Now/ });
}

test.describe('MixVy Stripe checkout contract', () => {
  test.skip(!hasCredentials, 'Run npm run test:e2e:provision-account first.');
  test.skip(
    !paymentsEnabled,
    'Set E2E_PAYMENTS_ENABLED=true for a web build compiled with ENABLE_PAYMENTS=true.',
  );
  test.beforeEach(({ browserName }) => {
    test.skip(
      browserName !== 'chromium',
      'Flutter web semantic checkout interactions are validated in Chromium.',
    );
  });

  test('sends the premium package and launches returned Stripe checkout', async ({
    page,
  }) => {
    let requestPayload: unknown;
    await page.route(checkoutFunctionPattern, async (route) => {
      requestPayload = route.request().postDataJSON();
      await route.fulfill({
        status: 200,
        contentType: 'application/json',
        body: JSON.stringify({ data: { url: checkoutUrl } }),
      });
    });
    await openPayments(page);

    const popupPromise = page.waitForEvent('popup');
    await upgradeButton(page).click();
    const checkoutPage = await popupPromise;

    expect(requestPayload).toMatchObject({
      data: { packageId: 'premium_access' },
    });
    await expect(checkoutPage).toHaveURL(/^https:\/\/checkout\.stripe\.com\//);
    await checkoutPage.close();
  });

  test('disables checkout while the callable request is pending', async ({ page }) => {
    let requestCount = 0;
    let releaseRequest: (() => void) | undefined;
    const requestPending = new Promise<void>((resolve) => {
      releaseRequest = resolve;
    });
    await page.route(checkoutFunctionPattern, async (route) => {
      requestCount += 1;
      await requestPending;
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({
          error: { status: 'INTERNAL', message: 'Checkout unavailable' },
        }),
      });
    });
    await openPayments(page);

    await upgradeButton(page).click();
    await expect.poll(() => requestCount).toBe(1);
    await expect(upgradeButton(page)).toHaveCount(0);
    releaseRequest?.();
    await expect(page.getByText(/Failed to create checkout session/)).toBeVisible();
    await expect(upgradeButton(page)).toBeEnabled();
  });

  test('shows an error and permits retry after callable failure', async ({ page }) => {
    let requestCount = 0;
    await page.route(checkoutFunctionPattern, async (route) => {
      requestCount += 1;
      await route.fulfill({
        status: 500,
        contentType: 'application/json',
        body: JSON.stringify({
          error: { status: 'UNAVAILABLE', message: 'Payment service unavailable' },
        }),
      });
    });
    await openPayments(page);

    await upgradeButton(page).click();
    await expect(page.getByText(/Failed to create checkout session/)).toBeVisible();
    await expect(upgradeButton(page)).toBeEnabled();
    await upgradeButton(page).click();
    await expect.poll(() => requestCount).toBe(2);
  });
});
