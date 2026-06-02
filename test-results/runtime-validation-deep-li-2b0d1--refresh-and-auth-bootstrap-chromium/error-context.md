# Instructions

- Following Playwright test failed.
- Explain why, be concise, respect Playwright best practices.
- Provide a snippet of code with the fix, if possible.

# Test info

- Name: runtime-validation.spec.ts >> deep link survives refresh and auth bootstrap
- Location: tests\runtime-validation.spec.ts:260:1

# Error details

```
Error: expect(locator).toBeVisible() failed

Locator: getByText(/Joining room/i).first()
Expected: visible
Timeout: 15000ms
Error: element(s) not found

Call log:
  - Expect "toBeVisible" with timeout 15000ms
  - waiting for getByText(/Joining room/i).first()

```

# Page snapshot

```yaml
- button "Enable accessibility" [ref=e2]
```

# Test source

```ts
  181 |   expect(summary.navigationLoopDetected).toBeFalsy();
  182 |   await writeSummary(testInfo, summary);
  183 | });
  184 | 
  185 | test('runtime console and network capture on target flows', async ({ page }, testInfo) => {
  186 |   test.setTimeout(240_000);
  187 |   const observer = new RuntimeObserver('runtime-capture');
  188 |   observer.attach(page);
  189 | 
  190 |   const flows = [
  191 |     '/',
  192 |     '/auth',
  193 |     '/home',
  194 |     '/profile/runtime-capture-profile',
  195 |     '/room/runtime-capture-room',
  196 |     '/create-room',
  197 |   ];
  198 | 
  199 |   for (const route of flows) {
  200 |     await go(page, observer, `${liveBaseUrl}${route}`);
  201 |     await waitForRouteSettle(page);
  202 |   }
  203 | 
  204 |   const summary = observer.summary(page.url());
  205 |   await writeSummary(testInfo, summary);
  206 | });
  207 | 
  208 | test('authenticated room creation validation', async ({ page }, testInfo) => {
  209 |   const observer = new RuntimeObserver('authenticated-room-creation-validation');
  210 |   observer.attach(page);
  211 | 
  212 |   const email = process.env.MIXVY_TEST_EMAIL;
  213 |   const password = process.env.MIXVY_TEST_PASSWORD;
  214 | 
  215 |   test.skip(
  216 |     !email || !password,
  217 |     'MIXVY_TEST_EMAIL and MIXVY_TEST_PASSWORD are required for authenticated room creation validation.',
  218 |   );
  219 | 
  220 |   await go(page, observer, `${liveBaseUrl}/auth`);
  221 |   await waitForFlutterWasmStable(page);
  222 |   await fillByPlaceholder(page, observer, 'Email address', email!);
  223 |   await fillByPlaceholder(page, observer, 'Password', password!);
  224 |   await clickButtonByName(page, observer, 'SIGN IN');
  225 | 
  226 |   await page.waitForURL(/\/(home|onboarding)(\?|$)/, { timeout: 30_000 });
  227 |   const postLoginUrl = page.url();
  228 | 
  229 |   if (/\/onboarding(\?|$)/.test(postLoginUrl)) {
  230 |     throw new Error(
  231 |       'Authenticated user was redirected to /onboarding. Complete legal acceptance for this test account, then rerun.',
  232 |     );
  233 |   }
  234 | 
  235 |   await go(page, observer, `${liveBaseUrl}/create-room`);
  236 |   await waitForFlutterWasmStable(page);
  237 | 
  238 |   const roomName = `PW Runtime ${Date.now()}`;
  239 |   await fillByPlaceholder(page, observer, 'e.g. Late Night Music Session', roomName);
  240 | 
  241 |   observer.recordAction('create-room-submit');
  242 |   await clickTextAnyRole(page, observer, /start\s+room\s+now/i, 'start-room-now');
  243 | 
  244 |   await page.waitForURL(/\/room\/[^/?#]+/, { timeout: 45_000 });
  245 |   await waitForFlutterWasmStable(page);
  246 | 
  247 |   const summary = observer.summary(page.url());
  248 |   const roomNavigations = summary.urlTransitions.filter((u) => /\/room\/[^/?#]+/.test(u)).length;
  249 |   expect(roomNavigations).toBe(1);
  250 |   expect(summary.actionCounts['create-room-submit']).toBe(1);
  251 |   expect(summary.duplicateActions).not.toContain('create-room-submit');
  252 |   expect(summary.navigationLoopDetected).toBeFalsy();
  253 | 
  254 |   // Strong signal for duplicate room write attempts in browser runtime traffic.
  255 |   expect(summary.roomWriteSignals).toBeLessThanOrEqual(1);
  256 | 
  257 |   await writeSummary(testInfo, summary);
  258 | });
  259 | 
  260 | test('deep link survives refresh and auth bootstrap', async ({ page }, testInfo) => {
  261 |   const observer = new RuntimeObserver('deep-link-survival');
  262 |   observer.attach(page);
  263 | 
  264 |   // Use a deterministic room ID for testing the deep link path
  265 |   const testRoomId = `pw-deep-link-test-${Date.now()}`;
  266 |   const deepLink = `${liveBaseUrl}/rooms/room/${testRoomId}`;
  267 | 
  268 |   // Navigate directly to the deep link
  269 |   observer.recordAction(`goto-deeplink:${deepLink}`);
  270 |   await page.goto(deepLink);
  271 | 
  272 |   // Wait for Flutter and Auth bootstrap
  273 |   await waitForFlutterWasmStable(page);
  274 | 
  275 |   // Expect to stay on the room route (or be redirected to auth if forced)
  276 |   // The crucial part is that it shouldn't get stuck on / or redirect to /home prematurely
  277 |   await expect(page).toHaveURL(new RegExp(`/rooms/room/${testRoomId}`), { timeout: 30000 });
  278 | 
  279 |   // Verify the 'Joining room' loading scaffold appears (means it successfully targeted the room)
  280 |   const joiningText = page.getByText(/Joining room/i).first();
> 281 |   await expect(joiningText).toBeVisible({ timeout: 15000 });
      |                             ^ Error: expect(locator).toBeVisible() failed
  282 | 
  283 |   const summary = observer.summary(page.url());
  284 |   await writeSummary(testInfo, summary);
  285 | });
  286 | 
```