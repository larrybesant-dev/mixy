# MixVy E2E Test Suite – Playwright

This directory contains **end-to-end tests** for the live MixVy application at `https://mixvy-v2.web.app`. These tests run against the deployed site without modifying any application code.

## 📋 Test Files Overview

| File | Purpose | Coverage |
|------|---------|----------|
| **01-auth-and-navigation.spec.ts** | Authentication & routing | Login form, branding, page navigation, session persistence |
| **02-gift-system-and-monetization.spec.ts** | Gift sending & coin system | Gift picker, allowance tracking, coin modal, animations, ticker |
| **03-stripe-payment-integration.spec.ts** | Payment flow & Stripe integration | Payment sheet, card fields, error handling, Cloud Functions |
| **04-responsive-design.spec.ts** | Mobile & responsive UX | Desktop/tablet/mobile viewports, touch targets, orientation changes |
| **05-performance-accessibility.spec.ts** | Performance & A11y | Load times, LCP/CLS, keyboard nav, screen reader support, contrast |

---

## 🚀 Quick Start

### 1. Install Playwright & Dependencies

```bash
npm install -D @playwright/test
```

Or if you're using the project's existing dependencies:

```bash
npm install
```

### 2. Install Browsers

```bash
npx playwright install
```

### 3. Run All Tests

```bash
npx playwright test
```

### 4. Run Specific Test File

```bash
npx playwright test e2e/01-auth-and-navigation.spec.ts
```

### 5. Run Tests in Headed Mode (See Browser)

```bash
npx playwright test --headed
```

### 6. Run Tests in UI Mode (Interactive)

```bash
npx playwright test --ui
```

### 7. Debug Tests

```bash
npx playwright test --debug
```

### 8. View Test Report

After tests run, view the HTML report:

```bash
npx playwright show-report
```

---

## ⚙️ Configuration

The `playwright.config.ts` is pre-configured to:
- **Base URL**: `https://mixvy-v2.web.app` (live deployment)
- **Browsers**: Chromium, Firefox, WebKit
- **Retries**: 2 retries on CI, 0 locally
- **Screenshots**: Captured on failure
- **Videos**: Recorded on failure
- **Traces**: Recorded on first retry

To run against a different environment, modify the `baseURL` in `playwright.config.ts`:

```typescript
use: {
  baseURL: 'http://localhost:3000', // or staging URL
  ...
}
```

---

## 📊 Test Categories

### Authentication & Navigation (`01-auth-*.spec.ts`)
- ✅ Auth form loads with correct buttons
- ✅ Email validation works
- ✅ Password field is secure (type="password")
- ✅ Session persistence across reloads
- ✅ Graceful network error handling

**To run**: `npx playwright test 01-auth`

### Gift System & Monetization (`02-gift-*.spec.ts`)
- ✅ Gift button visible in room
- ✅ Gift picker modal opens
- ✅ Recipient selection shows participants
- ✅ Gift items display correctly
- ✅ Free allowance badge shows count
- ✅ "Buy Coins Now" button appears when limit hit
- ✅ Coin packages display with pricing
- ✅ "Best Value" badge on recommended package
- ✅ Gift animations render
- ✅ Gift ticker shows recent gifts

**To run**: `npx playwright test 02-gift`

### Stripe Payment Integration (`03-stripe-*.spec.ts`)
- ✅ Payment sheet loads when coin purchase initiated
- ✅ Card input fields present
- ✅ Error handling for invalid cards
- ✅ Idempotency keys prevent duplicates
- ✅ Loading state during payment
- ✅ Success message displays
- ✅ Coin balance updates after purchase
- ✅ Cloud Functions integrate correctly
- ✅ Network timeouts handled gracefully

**To run**: `npx playwright test 03-stripe`

### Responsive Design (`04-responsive-*.spec.ts`)
- ✅ Desktop layout optimized (1920x1080)
- ✅ Tablet layout functional (768x1024)
- ✅ Mobile layout readable (375x667)
- ✅ Text readable without zoom (16px minimum)
- ✅ Touch targets 44x44px+ minimum
- ✅ No horizontal scroll on mobile
- ✅ Orientation changes handled
- ✅ Very small screens supported (280px)

**To run**: `npx playwright test 04-responsive`

### Performance & Accessibility (`05-performance-*.spec.ts`)
- ✅ Auth page loads < 3 seconds
- ✅ Home page loads < 4 seconds
- ✅ Cumulative Layout Shift (CLS) < 0.25
- ✅ Largest Contentful Paint (LCP) < 4s
- ✅ Proper heading hierarchy
- ✅ Alt text on images
- ✅ Link labels present
- ✅ Color contrast adequate
- ✅ Keyboard navigation works
- ✅ ARIA labels present
- ✅ Form labels associated
- ✅ Screen reader compatible
- ✅ No console errors

**To run**: `npx playwright test 05-performance`

---

## 🎯 Running in CI/CD

### GitHub Actions Example

```yaml
name: E2E Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 18
      - run: npm ci
      - run: npx playwright install --with-deps
      - run: npx playwright test
      - uses: actions/upload-artifact@v4
        if: always()
        with:
          name: playwright-report
          path: playwright-report/
```

---

## ⚠️ Important Notes

### Testing Live Production Site

1. **Avoid Destructive Actions**: These tests are read-only and don't delete data or trigger real payments
2. **Rate Limiting**: If you see "Too many login attempts", wait 15-20 minutes
3. **Test Accounts**: Sign up creates temporary accounts (clean up manually if needed)
4. **Network**: Tests require stable internet connection to reach `mixvy-v2.web.app`

### Mocking External Dependencies

Some tests use route interception to mock API responses without actually calling external services:

```typescript
await page.route('**/stripe.com/**', async route => {
  // Mock Stripe responses here
  await route.continue();
});
```

### Running Against Local/Staging

Change `baseURL` in `playwright.config.ts` or use environment variable:

```bash
PLAYWRIGHT_TEST_BASE_URL=http://localhost:3000 npx playwright test
```

---

## 🐛 Debugging Failed Tests

### Step 1: Run in UI Mode

```bash
npx playwright test --ui
```

This launches an interactive inspector where you can:
- Step through each test line-by-line
- Inspect the DOM at any point
- Replay failed tests
- See network requests

### Step 2: View Trace Files

Failed tests automatically save traces. View them:

```bash
npx playwright show-report
```

Then click a failed test to see the trace (DOM, network, console logs).

### Step 3: Use Debug Mode

```bash
npx playwright test --debug 01-auth-and-navigation.spec.ts
```

This opens a debugger where you can:
- Set breakpoints
- Inspect variables
- Step through code

### Step 4: Check Screenshots & Videos

Failed test artifacts are saved in `test-results/`:

```
test-results/
├── 01-auth-*.spec.ts-chromium/
│   ├── test-failed-1.png     # Screenshot
│   └── video.webm             # Recording
```

---

## 📝 Writing New Tests

Template for adding more tests:

```typescript
import { test, expect } from '@playwright/test';

test.describe('Feature Name', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
  });

  test('should do something', async ({ page }) => {
    // Arrange
    const element = page.locator('button:has-text("Click me")');

    // Act
    await element.click();
    await page.waitForTimeout(500);

    // Assert
    const result = page.locator('text=Success');
    await expect(result).toBeVisible();
  });

  test('should handle errors gracefully', async ({ page }) => {
    // Test error scenarios
    const error = page.locator('[role="alert"]');
    expect(await error.isVisible().catch(() => false)).toBeTruthy();
  });
});
```

---

## 🔗 Useful Resources

- [Playwright Documentation](https://playwright.dev/)
- [Playwright API Reference](https://playwright.dev/docs/api/class-page)
- [Best Practices](https://playwright.dev/docs/best-practices)
- [Debugging](https://playwright.dev/docs/debug)
- [CI/CD Integration](https://playwright.dev/docs/ci)

---

## 📊 Test Metrics

Track test results over time:

```bash
# Generate JSON report
npx playwright test --reporter=json > results.json

# Generate multiple formats
npx playwright test --reporter=html --reporter=json --reporter=junit
```

Reports are saved to `playwright-report/` by default.

---

## 🚨 Troubleshooting

### Tests timeout
```bash
# Increase timeout to 60 seconds
npx playwright test --timeout=60000
```

### Browser fails to launch
```bash
# Reinstall browsers
npx playwright install --with-deps
```

### Tests can't find elements
- Check selector with: `npx playwright test --headed --debug`
- Verify element exists: Inspect in browser console
- Try more specific selectors: Use `data-testid` attributes

### Rate limiting on login attempts
- Wait 15-20 minutes for Firebase to reset
- Or test with guest access if available
- Sign up creates new test accounts (safer than repeated login)

---

## ✅ Validation Checklist

Before merging code, run:

```bash
# Run all tests
npx playwright test

# Check a specific feature
npx playwright test --grep "Gift System"

# Ensure responsive design works
npx playwright test 04-responsive

# Check performance baseline
npx playwright test 05-performance
```

All tests should pass before production deployment! 🚀
