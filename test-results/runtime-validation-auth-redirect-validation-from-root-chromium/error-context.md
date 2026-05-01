# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: runtime-validation.spec.ts >> auth redirect validation from root
- Location: tests\runtime-validation.spec.ts:113:1

# Error details

```
Error: page.waitForFunction: Target page, context or browser has been closed
```

# Test source

```ts
  1   | import fs from 'node:fs/promises';
  2   | import path from 'node:path';
  3   | import { expect, test, type Page, type TestInfo } from '@playwright/test';
  4   | 
  5   | import { detectLiveMixVyUrl } from './helpers/live-url';
  6   | import { RuntimeObserver, type RuntimeSummary } from './helpers/runtime-observer';
  7   | 
  8   | let liveBaseUrl = '';
  9   | 
  10  | const artifactsDir = path.join('test-results', 'runtime-artifacts');
  11  | 
  12  | function slugify(input: string): string {
  13  |   return input
  14  |     .toLowerCase()
  15  |     .replace(/[^a-z0-9]+/g, '-')
  16  |     .replace(/(^-|-$)/g, '');
  17  | }
  18  | 
  19  | async function go(page: Page, observer: RuntimeObserver, url: string): Promise<void> {
  20  |   observer.recordAction(`goto:${url}`);
  21  |   await page.goto(url, { waitUntil: 'domcontentloaded' });
  22  | }
  23  | 
  24  | async function waitForFlutterWasmStable(page: Page): Promise<void> {
  25  |   // Flutter WASM can take extra time before first meaningful interaction.
  26  |   await page.waitForTimeout(3_500);
  27  |   await page.waitForLoadState('domcontentloaded');
  28  |   await page.waitForLoadState('networkidle').catch(() => {});
> 29  |   await page.waitForFunction(() => {
      |              ^ Error: page.waitForFunction: Target page, context or browser has been closed
  30  |     const hasFlutterNode = !!document.querySelector('flt-glass-pane, flt-semantics-host, canvas');
  31  |     const bodyText = (document.body?.innerText || '').trim();
  32  |     return hasFlutterNode || bodyText.length > 0;
  33  |   }, { timeout: 45_000 });
  34  |   await page.waitForTimeout(1_200);
  35  | }
  36  | 
  37  | async function waitForRouteSettle(page: Page): Promise<void> {
  38  |   await page.waitForLoadState('domcontentloaded');
  39  |   await page.waitForTimeout(1_100);
  40  | }
  41  | 
  42  | async function clickButtonByName(
  43  |   page: Page,
  44  |   observer: RuntimeObserver,
  45  |   buttonName: string,
  46  | ): Promise<void> {
  47  |   observer.recordAction(`click:${buttonName}`);
  48  |   const button = page.getByRole('button', { name: buttonName }).first();
  49  |   try {
  50  |     await expect(button).toBeVisible({ timeout: 15_000 });
  51  |     await button.click();
  52  |   } catch (error) {
  53  |     observer.recordSelectorFailure(`button:${buttonName}`, String(error));
  54  |     throw error;
  55  |   }
  56  | }
  57  | 
  58  | async function clickTextAnyRole(
  59  |   page: Page,
  60  |   observer: RuntimeObserver,
  61  |   textPattern: RegExp,
  62  |   actionLabel: string,
  63  | ): Promise<void> {
  64  |   observer.recordAction(`click:${actionLabel}`);
  65  |   const target = page.getByText(textPattern).first();
  66  |   try {
  67  |     await expect(target).toBeVisible({ timeout: 20_000 });
  68  |     await target.click();
  69  |   } catch (error) {
  70  |     observer.recordSelectorFailure(`text:${String(textPattern)}`, String(error));
  71  |     throw error;
  72  |   }
  73  | }
  74  | 
  75  | async function currentPath(page: Page): Promise<string> {
  76  |   return new URL(page.url()).pathname;
  77  | }
  78  | 
  79  | async function fillByPlaceholder(
  80  |   page: Page,
  81  |   observer: RuntimeObserver,
  82  |   placeholder: string,
  83  |   value: string,
  84  | ): Promise<void> {
  85  |   const input = page.getByPlaceholder(placeholder).first();
  86  |   try {
  87  |     await expect(input).toBeVisible({ timeout: 15_000 });
  88  |     await input.fill(value);
  89  |   } catch (error) {
  90  |     observer.recordSelectorFailure(`placeholder:${placeholder}`, String(error));
  91  |     throw error;
  92  |   }
  93  | }
  94  | 
  95  | async function writeSummary(testInfo: TestInfo, summary: RuntimeSummary): Promise<void> {
  96  |   await fs.mkdir(artifactsDir, { recursive: true });
  97  |   const fileName = `${slugify(testInfo.title)}.json`;
  98  |   const filePath = path.join(artifactsDir, fileName);
  99  |   await fs.writeFile(filePath, `${JSON.stringify(summary, null, 2)}\n`, 'utf8');
  100 |   await testInfo.attach('runtime-summary', {
  101 |     body: JSON.stringify(summary, null, 2),
  102 |     contentType: 'application/json',
  103 |   });
  104 | }
  105 | 
  106 | test.beforeAll(async () => {
  107 |   liveBaseUrl = await detectLiveMixVyUrl();
  108 |   process.env.PLAYWRIGHT_LIVE_URL = liveBaseUrl;
  109 |   // eslint-disable-next-line no-console
  110 |   console.log(`[runtime-suite] Using base URL: ${liveBaseUrl}`);
  111 | });
  112 | 
  113 | test('auth redirect validation from root', async ({ page }, testInfo) => {
  114 |   const observer = new RuntimeObserver('auth-redirect-validation');
  115 |   observer.attach(page);
  116 | 
  117 |   await go(page, observer, `${liveBaseUrl}/`);
  118 |   await waitForFlutterWasmStable(page);
  119 |   await expect(page).toHaveURL(/\/(auth|home)(\?|$)/, { timeout: 45_000 });
  120 | 
  121 |   const summary = observer.summary(page.url());
  122 |   expect(summary.navigationLoopDetected).toBeFalsy();
  123 |   await writeSummary(testInfo, summary);
  124 | });
  125 | 
  126 | test('guest mode validation and target route access', async ({ page }, testInfo) => {
  127 |   const observer = new RuntimeObserver('guest-mode-validation');
  128 |   observer.attach(page);
  129 | 
```